DIR=$HOME/nudger-gitops/smoke-tests
$DIR/grafana/smoke-curl.sh
$DIR/longhorn/longhorn-smoke.sh 
echo "je clean les pods"
$DIR/longhorn/longhorn-smoke.sh --cleanup
