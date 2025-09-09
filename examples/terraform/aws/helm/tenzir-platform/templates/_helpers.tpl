{{/*
Expand the name of the chart.
*/}}
{{- define "tenzir-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tenzir-platform.fullname" -}}
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
{{- define "tenzir-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tenzir-platform.labels" -}}
helm.sh/chart: {{ include "tenzir-platform.chart" . }}
{{ include "tenzir-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tenzir-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tenzir-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tenzir-platform.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "tenzir-platform.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Gateway labels
*/}}
{{- define "tenzir-platform.gateway.labels" -}}
{{ include "tenzir-platform.labels" . }}
app.kubernetes.io/component: gateway
{{- end }}

{{/*
Gateway selector labels
*/}}
{{- define "tenzir-platform.gateway.selectorLabels" -}}
{{ include "tenzir-platform.selectorLabels" . }}
app.kubernetes.io/component: gateway
{{- end }}

{{/*
UI labels
*/}}
{{- define "tenzir-platform.ui.labels" -}}
{{ include "tenzir-platform.labels" . }}
app.kubernetes.io/component: ui
{{- end }}

{{/*
UI selector labels
*/}}
{{- define "tenzir-platform.ui.selectorLabels" -}}
{{ include "tenzir-platform.selectorLabels" . }}
app.kubernetes.io/component: ui
{{- end }}

{{/*
API labels
*/}}
{{- define "tenzir-platform.api.labels" -}}
{{ include "tenzir-platform.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
API selector labels
*/}}
{{- define "tenzir-platform.api.selectorLabels" -}}
{{ include "tenzir-platform.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Generate domain names
*/}}
{{- define "tenzir-platform.baseDomain" -}}
{{- if .Values.global.randomSubdomain }}
{{- printf "tenant-%s.%s" (randAlphaNum 6 | lower) .Values.global.domain }}
{{- else }}
{{- .Values.global.domain }}
{{- end }}
{{- end }}

{{- define "tenzir-platform.apiDomain" -}}
{{- printf "api.%s" (include "tenzir-platform.baseDomain" .) }}
{{- end }}

{{- define "tenzir-platform.uiDomain" -}}
{{- printf "ui.%s" (include "tenzir-platform.baseDomain" .) }}
{{- end }}

{{- define "tenzir-platform.nodesDomain" -}}
{{- printf "nodes.%s" (include "tenzir-platform.baseDomain" .) }}
{{- end }}

{{/*
PostgreSQL connection string
*/}}
{{- define "tenzir-platform.postgresUri" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s-postgresql:5432/%s?sslmode=require" .Values.postgresql.auth.username "%s" (include "tenzir-platform.fullname" .) .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalPostgresql.uri }}
{{- end }}
{{- end }}

{{/*
MinIO endpoint
*/}}
{{- define "tenzir-platform.minioEndpoint" -}}
{{- if .Values.minio.enabled }}
{{- printf "http://%s-minio:9000" (include "tenzir-platform.fullname" .) }}
{{- else }}
{{- .Values.externalS3.endpoint }}
{{- end }}
{{- end }}