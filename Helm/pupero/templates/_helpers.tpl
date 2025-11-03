{{- define "pupero.labels" -}}
app.kubernetes.io/name: pupero
app.kubernetes.io/part-of: pupero
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
