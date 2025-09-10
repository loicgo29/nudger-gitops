 deux ClusterPolicy Kyverno :
	•	namespace-protect.yaml → rôle infrastructure : protéger certains namespaces d’un kubectl delete. C’est une policy ciblée namespaces, pas liée à la sécurité des Pods.
	•	nudger-security-guardrails.yaml → rôle sécurité Pod : règles d’hygiène (auto-harden, enforce rootfs RO, init root, justification d’exception).

👉 Donc :
	•	Toute règle qui touche aux Pods/containers (init, volumes, capabilities, readOnlyRootFilesystem, etc.) doit aller dans nudger-security-guardrails.yaml.
	•	Toute règle qui touche aux Namespaces (interdire suppression, labels obligatoires, etc.) va dans namespace-protect.yaml.
