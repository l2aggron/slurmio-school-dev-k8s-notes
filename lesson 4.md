---
date created: 2021-10-12 19:01:26 (+03:00), Tuesday
---

# Урок 4: Хранение конфигураций. Вечерняя школа «Kubernetes для разработчиков» [youtube](https://www.youtube.com/watch?v=-xZ02dEF6kU)


# Хранение конфигураций
- Каким образом в кластере k8s можно передавать конфигурации в наши приложения
    - Самый простой и неправильный вариант - захардкодить конфигурацию в контейнер и запускать приложение в таком неизменном виде. Не нужно так делать!
    - Более цивилизованные варианты

# Информация о ведущем (Добавить таймкод)

# Переменные окружения
- Работаем в каталоге `~/school-dev-k8s/practice/4.saving-configurations/1.env`
- Открываем манифест `deployment-with-env.yaml`
```yaml
# deployment-with-env.yaml
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
        env:            # Описываем желаемые переменные окружения
        - name: TEST    # Имя переменной окружения
          value: foo    # Значение переменной окружения
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 100Mi
          limits:
            cpu: 100m
            memory: 100Mi
...
```
- В этом манифесте мы указываем вариант доставки конфигураций внутрь нашего приложения так как это советует 12-factor applications, то есть, доставляем конфигурацию в виде переменных окружения
- У нас среда исполнения (docker, containerD, crio) позволяет при запуске процесса внутри контейнера создать этому процессу переменные окружения
- Самый простой вариант в kubernetes - описать все наши переменные окружения, который должны быть в контейнере, в манифесте (пода, репликасета, но как правило, это деплоймент)
- Смотрим в манифест, комментариями отмечен раздел с переменными окружения в описании контейнера
- Когда мы применим такой манифест в нашем кластере, в соответствующем контейнере появится переменная **TEST** со значением **foo**:
```shell
$ kubectl apply -f deployment-with-env.yaml

deployment.apps/my-deployment created

$ kubectl get pod

NAME                             READY   STATUS    RESTARTS   AGE
my-deployment-7b54b94746-blvpg   1/1     Running   0          26s

$ kubectl describe pod my-deployment-7b54b94746-blvpg

... # в выводе будет много информации, нас интересует данный блок, относящийся к контейнеру
    Environment:
      TEST:  foo # мы видим, что в контейнере создана переменная "TEST" со значением "foo"
...
```
- С помощью переменных окружения можно передавать различные конфигурации в наши приложения, соответственно, приложение будет считывать переменные окружения и применять их на своё усмотрение, например, таким образом можно передавать различные данные, как правило, конфигурационные
- Единственный, но достаточно большой минус такого подхода - если у вас есть повторяющиеся настройки для различных деплойментов, то нам придётся все эти настройки придется повторять для каждого деплоймента, например, если поменяется адрес БД, то его придётся изменить, скажем, в десятке деплойментов
- Как этого избежать? Очень просто:

# ConfigMap
- ConfigMap, как и всё в kubernetes, описывается в yaml файле, в котором, в формате key:value описаны настройки, которые можно использовать в нашем приложении
- в ConfigMap имеется раздел data, собственно там мы и задаём наши настройки, а потом этот словарь, этот ConfigMap, целиком указать в манифесте деплоймента, чтобы из него создать соответствующие переменные окружения в нашем контейнере
- Таким образом, за счёт ConfigMap мы можем уменьшить дублирование кода и упростить настройку однотипных приложений
- 
- В том же каталоге `~/school-dev-k8s/practice/4.saving-configurations/1.env`
- Открываем манифест `"configmap.yaml`
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-configmap-env
data:                   # интересующий нас раздел с настройками
  dbhost: postgresql    # параметр 1
  DEBUG: "false"        # параметр 2
...
```
- Применяем наш ConfigMap и смотрим что получилось
```shell
$ kubectl apply -f configmap.yaml

configmap/my-configmap-env created

$ kubectl get cm # cm - сокращение для configmap

NAME               DATA   AGE
kube-root-ca.crt   1      11d   # служебный configmap, созданный автоматически
my-configmap-env   2      79s   # результат наших действий
```
- DATA со значением 2 означает, что в данном конфигмапе находится 2 ключа

## Как использовать ConfigMap

### 1й вариант - через специально подготовленный манифест
```yaml
# deployment-with-env-cm.yaml
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
        env:
        - name: TEST
          value: foo
        envFrom:                    # раздел для загрузки переменных окружения извне
        - configMapRef:             # указываем, что будем брать их по ссылке на конфигмап
            name: my-configmap-env  # указываем наш объект ConfigMap, из которого будут загружаться данные
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 100Mi
          limits:
            cpu: 100m
            memory: 100Mi
...
```
- Результатом применения данного файла будет деплоймент, содержащий в себе контейнер с переменными окружения, прописанными в разделе DATA конфигмапа **my-configmap-env**
- Но если мы заглянем в информацию о созданном таким образом поде, то увидим похожую картину:
```shell
    Environment Variables from:
      my-configmap-env  ConfigMap  Optional: false
    Environment:
      TEST:  foo
```
- То есть, переменные, заданные через env мы можем видеть, а через envFrom - нет, только название объекта, из которого они загружаются
- Мы можем заглянуть в ConfigMap, чтобы увидеть, что должно быть записано в переменных окружения:
```shell
$ kubectl get cm my-configmap-env -o yaml

apiVersion: v1
data:                   # интересующий нас раздел
  DEBUG: "false"
  dbhost: postgresql
kind: ConfigMap
... # далее ещё много всего, в основном, создаваемые автоматически значения по умолчанию
```
- Также, мы можем сходить внутрь контейнера и через его шелл посмотреть переменные окружения, примерно так:
```shell
$ kubectl exec -it my-deployment-7d7cff784b-rjb55 -- bash
# "--" - это разделитель, обозначающий конец команды по отношению к kubectl и начало команды для пода
# в реультате выполнения увидим приглашение:
root@my-deployment-7d7cff784b-rjb55:/#
# выйти можно по сочетанию ctrl+d или командой exit

# также, мы можем сразу же обратиться к переменным окружения:
$ kubectl exec -it my-deployment-7d7cff784b-rjb55 -- env
# на выходе будет список всех переменных окружения
```

####  Что будет, если данные в ConfigMap поменяются?
- У запущенного контейнера переменные окружения поменять не так просто и kubernetes этим не занимается
- Если контейнер или под, уже запущены, то изменения ConfigMap на его переменных окружения не отразятся
- Таким образом, если мы хотим, чтобы приложения стало работать с новыми переменными окружения, для этого необходимо убить поды и создать новые

#### Q&A
- |
    - Q: Приоритет env и envFrom
    - A: Надо экспериментировать, возможно, зависит от порядка в манифесте
- |
    - Q: Что будет, если разные ConfigMap будут содержать одинаковые переменные
    - A: Вероятно, один из конфигмапов "победит"
### 

# Secret
- Используется для работы с чувствительными данными, такими как токены доступа, пароли, приватные ключи сертификатов
- Имеет структуру аналогичную ConfigMap, данные задаются в разделе data
- Бывает нескольких типов:
    - generic - самый распространенный тип, обычно используется для токенов и логинов с паролями
    - docker-registry - данные для авторизации в docker registry
        - фактически, является секретом с заранее определённым списком ключей в массиве data, содержит, в частности:
            - ключ, отвечающий за адрес репозитория
            - ключи, отвечающий за логин, пароль и почту
    - tls - предназначен для хранения сертификатов для шифрования данных, для HTTPS TLS протокола
        - как правило, используется в Ingress
        - имеет 2 предопределённых поля:
            - приватный ключ
            - сам подписанный сертификат

## Экспериментируем
### Создаём секрет
- Переходим в `~/school-dev-k8s/practice/4.saving-configurations/2.secret`
- Подсматриваем в **README.MD** и выполняем команды оттуда:
```shell
# создаём секрет
$ kubectl create secret generic test --from-literal=test1=asdf --from-literal=dbpassword=1q2w3e

secret/test created

$ kubectl get secret

NAME                  TYPE                                  DATA   AGE
default-token-wgc7r   kubernetes.io/service-account-token   3      11d
s024713-token-8vmmm   kubernetes.io/service-account-token   3      11d
test                  Opaque                                2      8s

$ kubectl get secret test -o yaml

apiVersion: v1
data:
  dbpassword: MXEydzNl
  test1: YXNkZg==
kind: Secret
metadata:
  creationTimestamp: "2021-10-12T17:43:10Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:data:
        .: {}
        f:dbpassword: {}
        f:test1: {}
      f:type: {}
    manager: kubectl-create
    operation: Update
    time: "2021-10-12T17:43:10Z"
  name: test
  namespace: s024713
  resourceVersion: "31214172"
  selfLink: /api/v1/namespaces/s024713/secrets/test
  uid: 9a98d624-1a40-40d0-a347-9feb852373ab
type: Opaque
```
- Важно! Секреты типа **kubernetes.io/service-account-token** удалять не нужно, т.к. они отвечают за работу с учебным кластером, они автоматически пересоздадутся, но доступ будет утерян
- При создании generic секрета мы получаем на выходе секрет с типом **Opaque**, что означает "непрозрачный". Данное расхождение в именовании сложилось исторически, все об этом знают и живут с этим.
- Заглядывая в вывод `kubectl get` мы видим, что значения секретов в разделе data отличаются от заданных, это они же, закодированные base64
- Важно понимать, что кодирование - это не шифрование и данные приводятся к исходному виду очень просто, без всяких ключей шифрования
- Зачем это нужно, если механизм декодирования так прост?
    - Одна из причин - обработанные таким образом строки хорошо воспринимаются yaml'ом, не нужно думать об экранировании
    - В kubernetes есть механизм RBAC, позволяющий ограничивать права пользователей на доступ к различным объектам kubernetes
        - По умолчанию, возможность просматривать и редактировать секреты через edit есть только у роли администраторов
        - Однако, не стоит забывать, что настройки, доставленные в приложение, могут быть обработаны этим самым приложением, так что, при желании, разработчики могут их получить. Обычно это уже головная боль специалистов по безопасности

### Работаем с деплойментом, который будет использовать наш секрет
```yaml
#deployment-with-secret.yaml
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
        envFrom:
        - configMapRef:
            name: my-configmap-env
        env:
        - name: TEST
          value: foo
        - name: TEST_1      # здесь мы можем указать название переменной, отличное от имени ключа в секрете или конфигмапе
          valueFrom:        # таким образом можно получать значения конкретных ключей из конфигмапов и секретов
            secretKeyRef:
              name: test
              key: test1
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 100Mi
          limits:
            cpu: 100m
            memory: 100Mi
...
```
- Применяем и смотрим что получилось:
```shell
$ kubectl apply -f deployment-with-secret.yaml

deployment.apps/my-deployment configured

$ kubectl get pod

NAME                             READY   STATUS    RESTARTS   AGE
my-deployment-57b8cc674c-qc9rk   1/1     Running   0          22s

$ kubectl describe pod my-deployment-57b8cc674c-qc9rk

# нас интересует данная секция:
...
    Environment Variables from:
      my-configmap-env  ConfigMap  Optional: false
    Environment:
      TEST:    foo
      TEST_1:  <set to the key 'test1' in secret 'test'>  Optional: false
...

```
- Видим, что в describe нашего объекта значение секрета скрыто
- Но если мы сходим внутрь пода через exec, то мы сможем увидеть содержимое переменных окружений (если такая возможность не отключена, как правило, именно так и поступают)

### stringData в секретах
- Пример манифеста:
```yaml
# secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: test
stringData:
  test: updated
...
```
- Мы видим, что здесь значение ключа test незакодировано
- Данный раздел был придуман для упрощения работы с секретами и их перекодировкой из/в base64
- Данные, занесенные в раздел stringData будут перенесены в секреты и закодированы соответствующим образом 
```shell
$ kubectl apply -f secret.yaml
Warning: resource secrets/test is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
secret/test configured
```
- В предупреждении речь идёт о том, что для корректной работы, а именно, для обработки мерджей конфигураций (активной и применяемой по apply), рекомендуется выполнять создание объектов определённым образом, иначе могут возникнуть побочные эффекты, а в нашем конкретном случае kubectl сам исправит данный недочёт
- В конце урока обещали скинуть ссылки на почитать
- После применения данного манифеста, если мы посмотрим на наш секрет, увидим следующее:
```shell
$ kubectl get secret test -o yaml
apiVersion: v1
data:
  dbpassword: MXEydzNl
  test: dXBkYXRlZA==
  test1: YXNkZg==
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{"annotations":{},"name":"test","namespace":"s024713"},"stringData":{"test":"updated"}}
# далее инфа, нам не актуальная
```
- В секции data добавился секрет test
- В аннотации добавился ключи last-applied-configuration, с информацией о применённых нами изменениях

- Почему это важно? Потому что, если мы попробуем исправить наш yaml (в нашем случае мы меняем имя ключа test на test1) и повторно выполнить apply, то мы увидим странное:
```shell
$ kubectl get secrets test -o yaml
apiVersion: v1
data:
  dbpassword: MXEydzNl
  test: ""
  test1: dXBkYXRlZA==
kind: Secret
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Secret","metadata":{"annotations":{},"name":"test","namespace":"s024713"},"stringData":{"test1":"updated"}}
# далее инфа, нам не актуальная
```
- Наш секрет записался в ключ test1, а значение ключа test обнулилось, т.к. за счёт данных в last-applied-configuration kubernetes понял, что раньше мы работали с ключом test, а теперь его нет
- Далее ведущий демонстрирует, что изменение секрета не затрагивает запущенный под, затем убивает его и проверяет, что в новом поде секрет обновился

## Q&A
- |
    - Q: А если надо передать IP новой POD'ы? Например, заскейлили новый memcached - приложению надо знать все IPs POD'ов memcached'а?
    - A: Это делается по другому, через сервисы, будет позже
- |
    - Q: Как из vault передавать пароли в кубер
    - A: Это есть в курсе Слёрм-Мега, если вкратце, в волте есть модуль для интеграции с kubernetes и можно научить приложение ходить в vault с токеном, который ему даст kubernetes и по этому токену брать данные из vault
- |
    - Q: Зачем "--" перед env в команде типа `kubectl exec -it my-deployment-7d7cff784b-rjb55 -- env`
    - A: Отвечает за разделение между окончанием команды kubectl и началом команды к поду

# Volumes ([таймкод](https://youtu.be/-xZ02dEF6kU?t=3665))
- Если вспомнить про docker, docker compose, то мы знаем, что системы исполнения контейнеров позволяют монтировать внутрь контейнера не просто переменные окружения, но еще и файлы, причём, монтировать файлы с диска внутрь контейнера
- В kubernetes пошли дальше и сделали возможность монтировать в контейнер содержимое секретов и конфигмапов в качестве файлов
- В ConfigMap можно указывать многострочные значения, затем к ним можно будет обратиться через секцию манифеста volumes, таким образом, в контейнер можно монтировать файлы, со значениями из ConfigMap, обычно там хранят целые конфигурации

## Экспериментируем ([таймкод](https://youtu.be/-xZ02dEF6kU?t=3756))
- Переходим в `~/school-dev-k8s/practice/4.saving-configurations/3.configmap`
- видим манифест ConfigMap с куском конфига nginx:
```yaml
# configmap.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-configmap
data:
  default.conf: |
    server {
        listen       80 default_server;
        server_name  _;

        default_type text/plain;

        location / {
            return 200 '$hostname\n';
        }
    }
...
```
- В данном случае, всё что после символа | - это многострочное значение ключа default.conf
- Многострочное значение оканчивается там, где отступ будет меньше чем в начале этого значения, т.е. на том же уровне, что и у ключа, в нашем случае default.conf
- Про многострочный текст через символ | можно почитать [здесь](https://habr.com/ru/post/270097/). Официальная документация для меня достаточно трудочитаема, кажется что-то из этого - [1](https://yaml.org/spec/1.2.2/#8111-block-indentation-indicator), [2](https://yaml.org/spec/1.2.2/#812-literal-style)
- Далее смотрим на манифест деплоймента:
```yaml
# deployment-with-configmap.yaml
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
        volumeMounts:                       # Здесь мы описываем точки монтирования томов внутри контейнера
        - name: config                      # Указываем имя тома для монтирования
          mountPath: /etc/nginx/conf.d/     # Здесь мы указываем точку монтирования 
      volumes:                          # Здесь (на уровень выше!) мы описываем тома
      - name: config                    # Задаём имя тому
        configMap:                      # Указываем, из какого конфигмапа создать том
          name: my-configmap
...
```
- Зачем делать это в 2 этапа, сначала формировать вольюм, затем подключать, почему сразу не подключить данные из конфигмапа в контейнер?
- Потому что обычно один и тот же том монтируют сразу в несколько контейнеров
- Аналогичные манипуляции можно применять не только к конфигмапам, но и к секретам
- Если мы применим данный конфигмап и деплоймент, то сможем увидеть в нашем контейнере файл, и его содержимое:
```shell
$ kubectl exec my-deployment-5dbbd56b95-xdb2j -- ls /etc/nginx/conf.d/

default.conf

$ kubectl exec my-deployment-5dbbd56b95-xdb2j -- cat /etc/nginx/conf.d/default.conf

server {
    listen       80 default_server;
    server_name  _;

    default_type text/plain;

    location / {
        return 200 '$hostname\n';
    }
}
```
- Причём, мы видим, что в созданном файле никаких лишних отступов, как при записи в yaml файле, нет
- Есть ограничения на размер создаваемых файлов (не понятно, техническое или речь о здравом смысле), не стоит создавать файлы по 20МБ

# Остановился [здесь](https://youtu.be/-xZ02dEF6kU?t=4214)