---
date created: 2021-10-15 16:02:06 (+03:00), Friday
---

# Урок 5: Хранение данных. Вечерняя школа «Kubernetes для разработчиков» [youtube](https://youtu.be/8Wk1iI8mMrw)

## Техническая пауза, опрос [00:00:20](https://youtu.be/8Wk1iI8mMrw?t=20)

## Вступление [00:04:15](https://youtu.be/8Wk1iI8mMrw?t=255)
- Сергей приводит в пример новичков, которые развернув "Hello World!" приложение в kubernetes радуются его неубиваемости и пробуют добавить в деплоймент образ какого нибудь MySQL, получают 3 отдельных базы а не какой-то кластер и спрашивают, почему так происходит.
- Происходит это потому, что kubernetes не знает ничего о базах данных и не умеет их "готовить"
- Зато kubernetes умеет предоставлять приложению место, где оно сможет хранить свои данные

## Хранение данных [00:06:48](https://youtu.be/8Wk1iI8mMrw?t=408)
- В kubernetes работает принцип good state - dead state (statless)
- Kubernetes изначально разрабатывался и предназначался для запуска микросервисов
    - Микросервисы, как правило, маленькие, быстрые, потребляющие мало ресурсов, их можно запускать в нужное количество реплик и вся нагрузка будет более или менее равномерно распределяться по всем репликам, отказ небольшой части реплик практически не скажется на работе сервиса, упавшие реплики будут восстановлены
- С приложениями, которые хранят состояние (state), вышеописанный подход не работает в полной мере, т.к. мы будем получать уникальные реплики
    - Например, приложение обслуживает бэкэнд личного кабинета и хранит состояние залогинившихся пользователей, если какая-то реплика умрёт, то пользователи, которых она обслуживала, вылетят из ЛК и им будет необходимо снова залогиниться
- Таким образом, хранить состояние внутри реплики - это плохая идея, есть более подходящие варианты:
    - Данные стоит хранить в базе данных
    - Данные, к которым нужен оперативный доступ стоит хранить в соответствующих решениях, например memcached, redis, tarantool и т.п.
    - Для файлов стоит использовать, например, S3-совместимое хранилище ([1](https://en.wikipedia.org/wiki/Amazon_S3), [2](https://habr.com/ru/post/318086/))
        - Хороший S3 может работать как CDN, например, вы загрузили в S3 файлик, отдали пользователю ссылку и пользователь сможет получить файл по этой ссылке прямо из S3 мимо основного бэкэнда
- Если всё таки очень хочется хранить состояние в репликах, то есть несколько способов, о них ниже

### HostPath [00:09:29](https://youtu.be/8Wk1iI8mMrw?t=569)
- Начнём разбирать с тома (volume), под названием HostPath
    - Когда на прошлых занятиях мы работали с ConfigMap, Secrets, мы их монтировали как файлы внутрь контейнера, мы столкнулись с двумя понятиями:
        - volumeMounts - точки монтирования внутри контейнера
        - volumes - тома, которые мы монтируем в эти точки
    - С томами, на которых можно хранить данные, всё работает так же:
        - у нас будет точка монтирования, volumeMount, где мы укажем, куда монтировать наш том
        - в разделе volumes мы будем указывать тип тома, в нашем случае это hostPath
- HostPath - аналог механизма из docker compose - мы берем каталог, который находится на ноде и монтируем этот каталог внутрь контейнера, таким образом приложение внутри контейнера получает доступ к каталогу, который находится на ноде
    - Вопрос в зрительский зал - насколько это хорошо с точки зрения безопасности?
        - Общее настроение - вариант плохой
    - Почему это плохой вариант?
        - Потому что такой механизм позволяет получить доступ к каталогам на уровне ноды, в некоторых сценариях этим могут воспользоваться злоумышленники, получившие доступ к контейнеру
            - В связи с этим в продакшн кластерах часто запрещают к использованию данный тип томов с помощью политик безопасности (pod security policy) или с помощью внешних валидаторов манифестов типа [gatekeeper](https://kubernetes.io/blog/2019/08/06/opa-gatekeeper-policy-and-governance-for-kubernetes/), к(у)верна? (не нашел ничего похожего в гугле)

#### Посмотрим, как это выглядит в yaml манифестах [00:12:25](https://youtu.be/8Wk1iI8mMrw?t=745)
- работаем в каталоге `~/school-dev-k8s/practice/5.saving-data/1.hostpath`
- смотрим содержимое манифеста деплоймента
```yaml
# deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - image: quay.io/testing-farm/nginx:1.12
        name: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 100Mi
          limits:
            cpu: 100m
            memory: 100Mi
        volumeMounts:         # раздел для указание точек монтирования
        - name: data          # имя тома
          mountPath: /files   # путь к точке монтирования (внутри пода)
      volumes:              # перечисление томов, которые будут смонитированы
      - name: data          # имя тома
        hostPath:           # тип тома
          path: /data_pod   # путь к каталогу (внутри узла)
...
```
- применяем деплоймент
```shell
$ kubectl apply -f deployment.yaml

deployment.apps/my-deployment created

$ kubectl get pod

No resources found in s024713 namespace.

$ kubectl get all

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-deployment   0/1     0            0           64s

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/my-deployment-f9c7845d9   1         0         0       64s
```
- видим, что что-то пошло не так - деплоймент создан, поды не появились, репликасет не перешёл в статус READY
- разбираемся
```shell
$ kubectl describe deployments.apps my-deployment

# часть вывода скрыта
# видим, что есть проблемы, но что именно не так, не понятно
Conditions:
  Type             Status  Reason
  ----             ------  ------
  Progressing      True    NewReplicaSetCreated
  Available        True    MinimumReplicasAvailable
  ReplicaFailure   True    FailedCreate
OldReplicaSets:    <none>
NewReplicaSet:     my-deployment-f9c7845d9 (0/1 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  4m10s  deployment-controller  Scaled up replica set my-deployment-f9c7845d9 to 1

$kubectl describe replicasets.apps my-deployment-f9c7845d9

# часть вывода скрыта
# видим сообщение от replicaset-controller о том что hostPath запрещён к использованию посредством PodSecurityPolicy
Conditions:
  Type             Status  Reason
  ----             ------  ------
  ReplicaFailure   True    FailedCreate
Events:
  Type     Reason        Age                     From                   Message
  ----     ------        ----                    ----                   -------
  Warning  FailedCreate  3m43s (x17 over 9m14s)  replicaset-controller  Error creating: pods "my-deployment-f9c7845d9-" is forbidden: PodSecurityPolicy: unable to admit pod: [spec.volumes[0]: Invalid value: "hostPath": hostPath volumes are not allowed to be used]
```

#### Q&A
- [01:16:23](https://youtu.be/8Wk1iI8mMrw?t=983)
    - Q: На какой ноде будет лежать каталог HostPath
    - A: Будет происходить попытка смонтировать каталог с той ноды, где запущен под
- [01:16:42](https://youtu.be/8Wk1iI8mMrw?t=1002)
    - Q:  Где управлять PodSecurityPolicy?
    - A: Рассмотрим позже, это отдельная трехчасовая лекция, эта тема есть в курсе "Мега", но здесь тоже будет обзорная лекция
- [01:17:03](https://youtu.be/8Wk1iI8mMrw?t=1023)
    - Q: По умолчанию все политики открыты?
    - A: Да, по умолчанию никаких psp не включено в kubernetes, их нужно специально включать для того чтобы можно было применять какие либо ограничения
- [00:17:12](https://youtu.be/8Wk1iI8mMrw?t=1032)
    - Q: Кажется, это ответ на эту ссылку ([PodSecurityPolicy Deprecation: Past, Present, and Future](https://kubernetes.io/blog/2021/04/06/podsecuritypolicy-deprecation-past-present-and-future/)), но она была воспринята как информация о прекращении поддержки hostPath
    - A: Такой тип в deprecated перейти не может, потому что он нужен для системных компонентов kubernetes, чтобы они запускались. Там решается проблема курицы и яйца, Мюнгхаузена, который вытаскивает себя из болота и т.д., грубо говоря, ему (кому?) нужно запуститься, пока еще не все компоненты запущены, поэтому приходится использовать hostPath для таких решений

### [EmptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) [00:17:47](https://youtu.be/8Wk1iI8mMrw?t=1067)
- Еще один вариант тома, т.н. [Ephemeral](https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/)
- В перводе с английского - пустой каталог
- Создаёт временный диск и монтирует его внутрь контейнера
- Т.е., это не заранее обозначенный каталог на ноде, а специальный каталог, создаваемый посредством container runtime interface, который будет использоваться в нашем контейнере всё время, пока живёт под
- После того, как под закончит свою работу (его выключат, обновят и т.п.), emptyDir будет удалён вместе с подом
- Таким образом, данные хранимые в emptyDir живут столько же, сколько и под, удалён под - удалены данные
- Если контейнер внутри пода упадёт, сохранность данных это не затронет
- Можно провести аналогию emptyDir со стандартным docker volume, при условии, что в манифесте docker compose мы не указываем, какой каталог монтировать, но указываем имя, будет создан volume, с тем отличием, что emptyDir будет удален при завершении работы пода

#### Зачем нужен EmptyDir? [00:19:23](https://youtu.be/8Wk1iI8mMrw?t=1163)
- emptyDir применяется для работы с данными, которые не имеет смысл хранить постоянно, например:
    - для временных баз данных, например для автотестов
    - при тестировании приложений и сервисов, требующих работы с диском

##### Пробуем применить EmptyDir в учебном кластере [00:20:50](https://youtu.be/8Wk1iI8mMrw?t=1250)
- Переходим в каталог `~/school-dev-k8s/practice/5.saving-data/2.emptydir`, видим манифест:
```yaml
# deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - image: quay.io/testing-farm/nginx:1.12
        name: nginx
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 100Mi
          limits:
            cpu: 100m
            memory: 100Mi
        volumeMounts:       
        - name: data
          mountPath: /files
      volumes:          # перечисление томов, которые будут смонитированы
      - name: data      # имя тома
        emptyDir: {}    # тип тома и пустой словарь в качестве значения, чтобы манифест прошел валидацию
...
```
- Видим знакомую картину, в разделе volumes подключаем том типа emptyDir
- Фигурные скобки в качестве значения переданы для того чтобы манифест прошел валидацию (непонятно только чью, попробовал убрать их, ошибок не встретил, подставил вместо них `~` - аналогично)
- Далее Сергей применяет манифест и демонстрирует, что мы можем писать в каталог /files, а также что после перезахода в контейнер, он остаётся на месте

#### Q&A
- [00:24:43](https://youtu.be/8Wk1iI8mMrw?t=1483)
    - Q: Ограничения на размер emptyDir?
    - A: Такие же как на том, где фактически расположен emptyDir, обычно это каталог  `/var/lib/kubelet/pods/_POD_ID_/volumes/kubernetes.io~empty-dir` или оперативная память
- [00:25:18](https://youtu.be/8Wk1iI8mMrw?t=1518)
    - Q: Можно ли создать emptyDir для нескольких подов?
    - A: Можно, но для каждого пода это будет отдельный emptyDir
- [00:25:30](https://youtu.be/8Wk1iI8mMrw?t=1530)
    - Q: А если apply - тоже пропадёт emptyDir?
    - A: Если произошли изменения, которые привели к созданию новых подов, то, как следствие, emptyDir пропадёт
- [00:25:57](https://youtu.be/8Wk1iI8mMrw?t=1557)
    - Q: Какой смысл использовать emptyDir, если можно положить данные в любую папку в контейнере и они так же не сохранятся при удалении пода
    - A: 
        - В связи со "слоёной" системой устройства хранилища в докер контейнере мы имеем большой оверхед по производительности, поэтому для работы используют механизм монтирования томов
        - Коллега подсказывают, что для обмена данными между разными контейнерами внутри одного пода тоже могут применяться emptyDir

### PV/PVC [00:27:32](https://youtu.be/8Wk1iI8mMrw?t=1652)
- Если кратко - более современные абстракции для работы с томами, подробнее в видео
- [Документация по Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

#### PVC, persistentVolumeClaim [00:29:20](https://youtu.be/8Wk1iI8mMrw?t=1760)
- Это наша заявка на то, какой диск нам нужен [00:33:15](https://youtu.be/8Wk1iI8mMrw?t=1995)
```yaml
# пример описания такого тома
volumes:                    # раздел объявления томов
  - name: mypd              # задаём имя
    persistentVolumeClaim:  # указываем тип тома
      claimName: myclaim    # название клэйма (да ладно?!)
```
- [00:29:43](https://youtu.be/8Wk1iI8mMrw?t=1783) - как это всё устроено
- [00:30:31](https://youtu.be/8Wk1iI8mMrw?t=1831) - обзор типов доступа к диску, то же в [документации](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes)

#### [Storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/) [00:31:24](https://youtu.be/8Wk1iI8mMrw?t=1884)
- В kubernetes для хранения данных (приложений?) обычно используются внешние системы хранения данных, такие как:
    - [Ceph](https://ceph.io/en/)
    - [Gluster](https://www.gluster.org/)
    - [LINSTOR](https://linbit.com/linstor/)
    - Различные аппаратные решения
    - Облачные решения - gcp, aws
- В storage class мы можем описать подключение к таким системам и указать данные для подключения, такие как:
    - адреса
    - логины/пароли/токены
    - различные другие настройки для взаимодействия с СХД

#### Persistent Volume [00:33:24](https://youtu.be/8Wk1iI8mMrw?t=2004)
- Абстракция, которая создаётся и в которой записывается информация о том диске, который был выдан нашему приложению 
- Откуда они беруться?
    - Один из вариантов - системный администратор СХД руками создаёт диски и с данными этих дисков создаёт манифесты PV в kubernetes