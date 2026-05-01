{{- define "jca-worker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jca-worker.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "jca-worker.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "jca-worker.envSecretName" -}}
{{- if .Values.secret.existingSecretName -}}
{{- .Values.secret.existingSecretName -}}
{{- else -}}
{{- printf "%s-env" (include "jca-worker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "jca-worker.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "jca-worker.fullname" .) .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "jca-worker.labels" -}}
app.kubernetes.io/name: {{ include "jca-worker.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "jca-worker.gatewayName" -}}
{{- printf "%s-gateway" (include "jca-worker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jca-worker.executorName" -}}
{{- printf "%s-executor" (include "jca-worker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
