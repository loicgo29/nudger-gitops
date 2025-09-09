flux get kustomizations -A
flux get helmreleases -A
flux logs -A --since=30m | egrep -i "fail|error|refused|timeout"
