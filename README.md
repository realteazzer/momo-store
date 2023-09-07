
# Momo Store aka Пельменная №2

<img width="900" alt="image" src="https://user-images.githubusercontent.com/9394918/167876466-2c530828-d658-4efe-9064-825626cc6db5.png">

Магазин доступен по [ссылке](https://pelmeni.teazzer.site/)

[Grafana](https://grafana.teazzer.site/)

[Prometheus](https://prometheus.teazzer.site/)


# Структура проекта

```bash
|
├── momo-store-app              - код программы
|   └── backend                 - код бэкенда и пайплайн для сборки и упаковки контейнера
|   └── frontend                - код фронтенда и пайплайн для сборки и упаковки контейнера
├── infrastructure              - терраформ файлы для инфраструктуры, чарты для приложения и мониторинга
|   └── helm                    - чарты приложения и gitlab пайплайн
|   └── kubernetes              - k8s манифесты приложения
|   └── terraform               - терраформ файлы для создания управляемого кластера и сети в Яндекс Облаке
|   └── monitoring-tools        - чарты для графаны и прометеуса
├── templates                   - шаблоны используемые в пайплайне
├── images                      - фото продуктов магазина (для загрузки в бакет)
└── .gitlab-ci.yml              - родительский пайплайн для сборки и релиза образов бэкенда и фронтенда в Container Registry, и сборку и загрузку helm чартов
```

## CI/CD

- развертывание приложение осуществляется с использованием [Downstream pipeline](https://docs.gitlab.com/ee/ci/pipelines/downstream_pipelines.html#parent-child-pipelines) 
- при изменениях в соответствующих директориях триггерятся pipeline для backend, frontend и infrastructure (helm)
- backend и frontend проходят этапы сборки, тестирования, релиза. Возможен деплой "по кнопке" в кластер 
- helm сборка пакета и загрузка в Nexus. Возможен деплой "по кнопке" в кластер 

## Infrastructure

- код ---> [Gitlab](https://gitlab.praktikum-services.ru/)
- helm-charts ---> [Nexus](https://nexus.praktikum-services.ru/)
- анализ кода ---> [SonarQube](https://sonarqube.praktikum-services.ru/)
- docker-images ---> Gitlab Container Registry
- терраформ бэкэнд и статика ---> [Yandex Object Storage](https://cloud.yandex.ru/services/storage)
- продакшн ---> [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)

# Развертывание инфраструктуры

## 1. Установить консоль управления YC, зарегистрировать аккаунт, настроить terraform 
Следовать [инструкции](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)

## 2. Создать хранилище
Создать 2 бакета:
  -  Публичный, для хранения статики (изображений товаров)
  -  С ограниченным доступом и шифрованием (для хранения terraform state)
Также создать сервисный аккаунт с правами kms.keys.encrypterDecrypter и storage.uploader, создать статический ключ и добавить его в переменные
```bash
export AWS_ACCESS_KEY_ID="<идентификатор_ключа>"
export AWS_SECRET_ACCESS_KEY="<секретный_ключ>"
```
## 3. Развернуть инфраструктуру
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```
В терраформ файлах используются модули [terraform-yc-kubernetes](https://github.com/terraform-yc-modules/terraform-yc-kubernetes) и [terraform-yc-vpc](https://github.com/terraform-yc-modules/terraform-yc-vpc)

## 4. Создать kubeconfig файл
  - получить креды
```bash
yc managed-kubernetes cluster get-credentials --id <id_кластера> --external
```
  - проверка доступности кластера:
```bash
kubectl cluster-info
```
  - сделать бэкап текущего ./kube/config:
```bash
cp ~/.kube/config ~/.kube/config.bak
```
  - создать манифест admin-user-service-account.yaml:

```bash
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```
  и применить его:
```bash
kubectl apply -f admin-user-service-account.yaml
```
  - получить endpoint: публичный ip адрес находится по пути Managed Service for Kubernetes/Кластеры/ваш_кластер -> обзор -> основное -> Публичный IPv4

  - получить KUBE_TOKEN:
```bash
kubectl -n kube-system get secrets -o json | jq -r '.items[] | select(.metadata.name | startswith("admin-user")) | .data.token' | base64 --decode
```
В Kubernetes с версии 1.24 не генерируется автоматически секрет для сервисного аккаунта, следует создать его самостоятельно (например [так](https://fabianlee.org/2022/10/16/kubernetes-ksa-must-now-create-secret-token-manually-as-of-kubernetes-1-24/)) 
  - сгенерировать конфиг:
```bash
export KUBE_URL=https://<см. пункт выше>   # Важно перед IP указать https://
export KUBE_TOKEN=<см.пункт выше>
export KUBE_USERNAME=admin-user
export KUBE_CLUSTER_NAME=<id_кластера> как в пункте_3

kubectl config set-cluster "$KUBE_CLUSTER_NAME" --server="$KUBE_URL" --insecure-skip-tls-verify=true
kubectl config set-credentials "$KUBE_USERNAME" --token="$KUBE_TOKEN"
kubectl config set-context default --cluster="$KUBE_CLUSTER_NAME" --user="$KUBE_USERNAME"
kubectl config use-context default
```
## 5. Установка Ingress-контроллера NGINX с менеджером для сертификатов Let's Encrypt

Следовать [инструкции](https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager)

## Подготовка Gitlab для работы пайплайнов
В CI/CD->Variables добавить следующие переменные:
 - GITLAB_TOKEN - gitlab токен
 - GITLAB_USER_LOGIN - gitlab логин
 - KUBECONF - kubeconfig из п.4 Инфраструктуры в base64 (cat ~/.kube/config | base64 )
 - NEXUS_HELM_REPO - адрес Nexus репозитроя для helm 
 - NEXUS_REPO_USER - логин Nexus
 - NEXUS_REPO_PASS - пароль Nexus
 - SONAR_LOGIN - логин SonarQube 
 - SONAR_URL - адрес SonarQube 
 - SONAR_FRONTEND_KEY - ключ для проекта фронтенда в SonarQube
 - SONAR_BACKEND_KEY - ключ для проекта бэкенда в SonarQube

В проекте мажорные версии задаются вручную в momo-store-app/backend/.gitlab-ci.yml и momo-store-app/frontend/.gitlab-ci.yml, патчверсии задаются с помощью CI_PIPELINE_ID

В helm чартах и k8s манифестах в секретах добавить docker-конфиг для загрузки образов из Container Registry 

1) залогиниться в Container Registry 
```bash
docker login gitlab.praktikum-services.ru:5050
```
2) Создать конфиг для подключения Container Registry
```bash  
cat ~/.docker/config.json | base64 -w 0 
```

3) добавить в secrets.yaml
```bash
---
kind: Secret
apiVersion: v1
metadata:
  name: docker-config-secret
data:
  .dockerconfigjson: >-
СЮДА
type: kubernetes.io/dockerconfigjson
```

# Мониторинг
## 1. Установить Prometheus
```bash
cd infrastructure/monitoring-tools
helm upgrade --install --atomic prometheus prometheus
```
## 2. Установить Grafana 
Указать в values хост для веб-интерфейса графаны
В ingress указать ID сертификата 

```bash
cd infrastructure/monitoring-tools
helm upgrade --install --atomic grafana grafana
```

## 3. Добавить Prometheus как Data source 
В Grafana открыть Configuration->Data Sources и добавить Prometheus (http://prometheus:9090)

<img width="900" alt="image" src="https://storage.yandexcloud.net/pelmeni-teazzer-pictures/Screenshot_155.png">


Backlog:
Переделать сборку бэкенда (собрать в контейнере https://klotzandrew.com/blog/smallest-golang-docker-image)
