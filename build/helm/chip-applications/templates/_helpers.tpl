
{{/*
Define argoCD Namespace
*/}}
{{- define "argocdNamespace.helper" -}}
{{- if .Values.argocdNamespace -}}
  {{- .Values.argocdNamespace | trim -}}
{{- else -}}
  {{- .Release.Namespace | trim -}}
{{- end -}}
{{- end }}

{{- define "additionalCert" -}}
{{- $expose := .Values.expose }}
{{- and $expose (hasKey $expose "tls") $expose.tls (hasKey $expose "additionalDnsNames") (gt (len $expose.additionalDnsNames) 0) -}}
{{- end }}

{{/*
Define Application's name
*/}}
{{- define "appName.helper" -}}
  {{- $app := default (dict) .Values.app -}}
  {{- $segments := list -}}
  {{- $name := default .Release.Name $app.name -}}
  {{- if $name -}}
    {{- $segments = append $segments $name -}}
  {{- end -}}
  {{- if $app.index -}}
    {{- $segments = append $segments ($app.index | toString) -}}
  {{- end -}}
  {{- $env := default .Values.clusterEnvironment $app.environment -}}
  {{- if $env -}}
    {{- $segments = append $segments $env -}}
  {{- end -}}
  {{- join "-" $segments | trimSuffix "-" -}}
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
