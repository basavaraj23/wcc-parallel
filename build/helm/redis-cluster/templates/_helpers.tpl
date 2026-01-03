{{- define "redis-cluster.fullname" -}}
{{- if .Values.clusterName -}}
{{- .Values.clusterName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "redis-cluster.chart" . -}}
{{- end -}}
{{- end -}}

{{- define "redis-cluster.masterName" -}}
{{- printf "%s-master" (include "redis-cluster.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "redis-cluster.replicaName" -}}
{{- printf "%s-replica" (include "redis-cluster.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "redis-cluster.labels" -}}
app.kubernetes.io/name: {{ include "redis-cluster.chart" . }}
app.kubernetes.io/instance: {{ include "redis-cluster.fullname" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "redis-cluster.selectorLabels" -}}
app.kubernetes.io/instance: {{ include "redis-cluster.fullname" .context }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "redis-cluster.chart" -}}
{{- printf "%s" .Chart.Name -}}
{{- end -}}

{{- define "redis-cluster.authSecret" -}}
{{- required "auth.existingSecret is required" .Values.auth.existingSecret -}}
{{- end -}}

{{- define "redis-cluster.passKey" -}}
{{- if .Values.auth.existingSecretPasswordKey -}}
{{- .Values.auth.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}
