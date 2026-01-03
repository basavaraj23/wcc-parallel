
{{/*
Define argoCD Namespace
*/}}
{{- define "argocdNamespace.helper" -}}
  argo-1-{{ .Values.clusterEnvironment }}
{{- end }}

{{- define "additionalCert" -}}
{{- $expose := .Values.expose }}
{{- and $expose (hasKey $expose "tls") $expose.tls (hasKey $expose "additionalDnsNames") (gt (len $expose.additionalDnsNames) 0) -}}
{{- end }}

{{/*
Define Application's name
*/}}
{{- define "appName.helper" -}}
  {{- $name := .Values.app.name  -}}
  {{- $index := .Values.app.index | toString -}}
  {{- $env := .Values.app.environment | default .Values.clusterEnvironment -}}
  {{- printf "%s-%s-%s" $name $index $env | trimSuffix "-" -}}
{{- end }}

{{/*
Define Application's namespace
*/}}
{{- define "appNamespace.helper" -}}
{{- if .Values.namespaceOverride -}}
{{- .Values.namespaceOverride | trim -}}
{{- else -}}
{{- .Release.Namespace | trim -}}
{{- end -}}
{{- end -}}


{{/*
Define Additional Cert Name
*/}}
{{- define "additionalCertName.helper" -}}
{{- $ns := (include "appNamespace.helper" .) | trim -}}
{{- $app := required "Values.app.name is required" .Values.app.name -}}
{{- printf "%s-%s-certificate" $ns $app -}}
{{- end -}}

{{/*
Define DNS target
*/}}
{{- define "externalDnsTarget.helper" -}}
{{- $dnsTargetIPs := .Values.ingress.dnsTargetIPs | default (list) -}}
{{- $externalIPs := .Values.ingress.externalIPs | default (list) -}}
{{- $targets := ternary $dnsTargetIPs $externalIPs (gt (len $dnsTargetIPs) 0) -}}
{{- join "," $targets -}}
{{- end -}}
