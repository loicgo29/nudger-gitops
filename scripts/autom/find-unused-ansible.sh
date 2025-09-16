#!/usr/bin/env bash
set -euxo pipefail

echo "🔍 Recherche des fichiers Ansible non utilisés..."

# 1. Lister tous les fichiers ansible (playbooks + roles + vars)
all_files=$(find tools/ansible -type f \( -name "*.yaml" -o -name "*.yml" \))

# 2. Extraire les rôles appelés dans les playbooks
used_roles=$(
  yq e '.. | select(has("roles")) | .roles[].role // empty' tools/ansible/playbooks/*.yaml 2>/dev/null \
  | sort -u
)

# 3. Extraire les playbooks inclus
used_playbooks=$(
  yq e '.. | select(has("import_playbook")) | .import_playbook // empty' tools/ansible/playbooks/*.yaml 2>/dev/null \
  | sort -u
)

# 4. Extraire les tasks incluses
used_tasks=$(
  yq e '.. | select(has("include_tasks")) | .include_tasks // empty' tools/ansible/roles/*/tasks/*.yaml 2>/dev/null \
  | sort -u
)

# 5. Marquer les fichiers utilisés
declare -A refs

# Associe les rôles -> tasks/main.yaml
for r in $used_roles; do
  role_path="tools/ansible/roles/$r/tasks/main.yaml"
  [[ -f "$role_path" ]] && refs["$role_path"]="playbook"
  # defaults/main.yml liés au rôle
  def_path="tools/ansible/roles/$r/defaults/main.yml"
  [[ -f "$def_path" ]] && refs["$def_path"]="role"
done

# Associe les playbooks inclus
for p in $used_playbooks; do
  [[ -f "tools/ansible/playbooks/$p" ]] && refs["tools/ansible/playbooks/$p"]="import_playbook"
done

# Associe les tasks incluses
for t in $used_tasks; do
  [[ -f "tools/ansible/roles/$t" ]] && refs["tools/ansible/roles/$t"]="include_tasks"
done

# group_vars/all.yaml → toujours utilisé
[[ -f tools/ansible/group_vars/all.yaml ]] && refs["tools/ansible/group_vars/all.yaml"]="group_vars"

echo "────────────────────────────"
for file in $all_files; do
  rel=$(realpath --relative-to=. "$file")
  if [[ -n "${refs[$rel]:-}" ]]; then
    echo "✅ Utilisé : $rel (via ${refs[$rel]})"
  else
    echo "❌ Non utilisé : $rel"
  fi
done
