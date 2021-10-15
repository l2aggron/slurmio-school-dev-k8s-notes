---
date created: 2021-10-15 16:02:06 (+03:00), Friday
---

# Урок 5: Хранение данных. Вечерняя школа «Kubernetes для разработчиков» [youtube](https://youtu.be/8Wk1iI8mMrw)
## [Техническая пауза, опрос](https://youtu.be/8Wk1iI8mMrw?t=20)
## [Вступление](https://youtu.be/8Wk1iI8mMrw?t=255)
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
# видим, что hostPath запрещён к использованию посредством PodSecurityPolicy
Conditions:
  Type             Status  Reason
  ----             ------  ------
  ReplicaFailure   True    FailedCreate
Events:
  Type     Reason        Age                     From                   Message
  ----     ------        ----                    ----                   -------
  Warning  FailedCreate  3m43s (x17 over 9m14s)  replicaset-controller  Error creating: pods "my-deployment-f9c7845d9-" is forbidden: PodSecurityPolicy: unable to admit pod: [spec.volumes[0]: Invalid value: "hostPath": hostPath volumes are not allowed to be used]
```
- Остановился [здесь](https://youtu.be/8Wk1iI8mMrw?t=907)
