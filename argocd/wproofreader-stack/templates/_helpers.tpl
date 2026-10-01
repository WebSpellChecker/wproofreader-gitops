{{/* Common Application skeleton pieces */}}
{{- define "stack.valuesSource" -}}
- repoURL: {{ .Values.gitops.repoURL }}
  targetRevision: {{ .Values.gitops.revision }}
  ref: values
{{- end -}}
{{- define "stack.destination" -}}
server: https://kubernetes.default.svc
namespace: {{ .Values.namespace }}
{{- end -}}
