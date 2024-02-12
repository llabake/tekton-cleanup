# FROM ghcr.io/ctron/kubectl:1.19.15
FROM ghcr.io/ctron/kubectl:1.19.15

# Copy the tekton pipeline run cleanup script
COPY tekton-pipeline-cleanup.sh /root/tekton-pipeline-cleanup.sh
