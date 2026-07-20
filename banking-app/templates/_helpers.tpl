{{/*
Common labels applied to every resource this chart creates.
*/}}
{{- define "banking-app.labels" -}}
app.kubernetes.io/part-of: banking-app
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Per-service selector labels — used by BOTH the blue and green Deployments
(with an added `slot` label) and by the Services that pick one slot or the
other.
*/}}
{{- define "banking-app.selectorLabels" -}}
app: {{ .service }}
{{- end }}
