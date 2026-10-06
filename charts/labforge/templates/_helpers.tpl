{{- define "labforge.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "labforge.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "labforge.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "labforge.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "labforge.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "labforge.labels" -}}
app.kubernetes.io/name: {{ include "labforge.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
