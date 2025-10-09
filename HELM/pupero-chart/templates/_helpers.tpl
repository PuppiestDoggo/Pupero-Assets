{{/*
Expand the name of the chart.
*/}}
{{- define "pupero.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "pupero.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pupero.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pupero.labels" -}}
helm.sh/chart: {{ include "pupero.chart" . }}
{{ include "pupero.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pupero.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pupero.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pupero.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pupero.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create full image path with registry
*/}}
{{- define "pupero.image" -}}
{{- $ctx := .context | default . -}}
{{- $registry := $ctx.Values.global.imageRegistry -}}
{{- $repository := .repository -}}
{{- $tag := .tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{/*
Database connection string
*/}}
{{- define "pupero.databaseUrl" -}}
mariadb+mariadbconnector://root:{{ .Values.global.database.rootPassword }}@{{ include "pupero.fullname" . }}-database:3306/{{ .Values.global.database.name }}
{{- end }}

{{/*
RabbitMQ connection string
*/}}
{{- define "pupero.rabbitmqUrl" -}}
amqp://{{ .Values.global.rabbitmq.user }}:{{ .Values.global.rabbitmq.password }}@{{ include "pupero.fullname" . }}-rabbitmq:5672/%2F
{{- end }}

{{/*
Monero RPC URL
*/}}
{{- define "pupero.moneroRpcUrl" -}}
http://{{ include "pupero.fullname" . }}-wallet-rpc:{{ .Values.global.monero.walletRpcPort }}
{{- end }}
