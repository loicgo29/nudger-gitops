./grafana/smoke-curl.sh
./longhorn/longhorn-smoke.sh 
echo "je clean les pods"
./longhorn/longhorn-smoke.sh --cleanup
