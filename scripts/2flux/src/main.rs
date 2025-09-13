use anyhow::{bail, Context, Result};
use serde::Deserialize;
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::process::Command;

#[derive(Debug, Deserialize)]
struct Meta {
    name: String,
    namespace: Option<String>,
}
#[derive(Debug, Deserialize, Clone)]
struct Condition {
    #[serde(rename = "type")]
    cond_type: String,
    status: Option<String>,
    reason: Option<String>,
    message: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct Meta {
    name: String,
    namespace: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct Status {
    conditions: Option<Vec<Condition>>,
    #[serde(default)]
    inventory: Option<Inventory>,
}

#[derive(Debug, Deserialize, Clone)]
struct Inventory {
    entries: Option<Vec<InventoryEntry>>,
}

#[derive(Debug, Deserialize, Clone)]
struct InventoryEntry {
    id: String,
}

#[derive(Debug, Deserialize, Clone)]
struct Common {
    metadata: Meta,
    status: Option<Status>,
    spec: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
struct Condition {
    #[serde(rename = "type")]
    cond_type: String,
    status: Option<String>,
    reason: Option<String>,
    message: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Common {
    metadata: Meta,
    status: Option<Status>,
    spec: Option<Value>,
}

#[derive(Debug, Deserialize)]
struct Status {
    conditions: Option<Vec<Condition>>,
    #[serde(default)]
    inventory: Option<Inventory>,
}

#[derive(Debug, Deserialize)]
struct Inventory {
    entries: Option<Vec<InventoryEntry>>,
}

#[derive(Debug, Deserialize)]
struct InventoryEntry {
    id: String,
}

/// Run a `flux get ... -o json` and parse items
fn flux_get(kind: &str, args: &[&str]) -> Result<Vec<Common>> {
    let out = Command::new("flux")
        .args(["get", kind])
        .args(args)
        .args(["-o", "json"])
        .output()
        .with_context(|| format!("running flux get {kind}"))?;

    if !out.status.success() {
        bail!(
            "flux get {kind} failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }
    let v: Value = serde_json::from_slice(&out.stdout)?;
    // two possible shapes: {"items":[...]} or a single object
    let items = if let Some(items) = v.get("items") {
        items.as_array().cloned().unwrap_or_default()
    } else {
        vec![v]
    };

    let mut res = Vec::new();
    for it in items {
        // normalize to Common
        let c: Common = serde_json::from_value(it)?;
        res.push(c);
    }
    Ok(res)
}

#[derive(Default)]
struct Edge {
    from: String,
    to: String,
}

fn status_badge(conds: &Option<Vec<Condition>>) -> &'static str {
    // Very light heuristic:
    if let Some(cs) = conds {
        // If any Ready==True => ✅, Ready==False => ❌, Unknown/Progressing => …
        for c in cs {
            if c.cond_type == "Ready" {
                match c.status.as_deref() {
                    Some("True") => return " ✅",
                    Some("False") => return " ❌",
                    _ => {}
                }
            }
        }
        // Reconciling True → " …"
        for c in cs {
            if c.cond_type == "Reconciling" && c.status.as_deref() == Some("True") {
                return " …";
            }
        }
        // Suspended? (some lists expose Suspended separately; keep simple)
        for c in cs {
            if c.reason.as_deref() == Some("Suspended") {
                return " ⏸️";
            }
        }
    }
    ""
}

fn label(kind: &str, meta: &Meta, conds: &Option<Vec<Condition>>) -> String {
    let ns = meta.namespace.as_deref().unwrap_or("-");
    format!(
        "{} {}/{}{}",
        kind,
        ns,
        meta.name,
        status_badge(conds)
    )
}

fn main() -> Result<()> {
    // Collect objects
    let gits = flux_get("sources", &["git", "-A"]).unwrap_or_default();
    let helmsrcs = flux_get("sources", &["helm", "-A"]).unwrap_or_default();
    let kustomizations = flux_get("kustomizations", &["-A"]).unwrap_or_default();
    let helmreleases = flux_get("helmreleases", &["-A"]).unwrap_or_default();

    // Index HelmRepository by (name,namespace)
    let mut helm_repo_index = BTreeMap::new();
    for hr in &helmsrcs {
        helm_repo_index.insert(
            (hr.metadata.name.clone(), hr.metadata.namespace.clone().unwrap_or_else(|| "flux-system".into())),
            label("HelmRepository", &hr.metadata, &hr.status.as_ref().and_then(|s| s.conditions.clone())),
        );
    }

    // Index GitRepository names
    let mut git_repo_index = BTreeMap::new();
    for g in &gits {
        git_repo_index.insert(
            (g.metadata.name.clone(), g.metadata.namespace.clone().unwrap_or_else(|| "flux-system".into())),
            label("GitRepository", &g.metadata, &g.status.as_ref().and_then(|s| s.conditions.clone())),
        );
    }

    // Build edges
    let mut edges: BTreeSet<(String, String)> = BTreeSet::new();
    let mut nodes: BTreeSet<String> = BTreeSet::new();

    // Add all nodes we’ll reference
    for k in &kustomizations {
        nodes.insert(label("Kustomization", &k.metadata, &k.status.as_ref().and_then(|s| s.conditions.clone())));
    }
    for hr in &helmreleases {
        nodes.insert(label("HelmRelease", &hr.metadata, &hr.status.as_ref().and_then(|s| s.conditions.clone())));
    }
    for (_, l) in &git_repo_index {
        nodes.insert(l.clone());
    }
    for (_, l) in &helm_repo_index {
        nodes.insert(l.clone());
    }

    // Edges: GitRepository -> Kustomization (via k.spec.sourceRef)
    for k in &kustomizations {
        if let Some(spec) = &k.spec {
            if let Some(sr) = spec.get("sourceRef") {
                let kind = sr.get("kind").and_then(|x| x.as_str()).unwrap_or("");
                let name = sr.get("name").and_then(|x| x.as_str()).unwrap_or("");
                let ns = sr.get("namespace").and_then(|x| x.as_str()).unwrap_or("flux-system");
                if kind.eq_ignore_ascii_case("GitRepository") {
                    if let Some(glab) = git_repo_index.get(&(name.to_string(), ns.to_string())) {
                        let from = glab.clone();
                        let to = label("Kustomization", &k.metadata, &k.status.as_ref().and_then(|s| s.conditions.clone()));
                        edges.insert((from, to));
                    }
                }
            }
        }
    }

    // Edges: Kustomization -> HelmRelease (scan inventory entries)
    for k in &kustomizations {
        let kinv = k.status.as_ref().and_then(|s| s.inventory.as_ref()).and_then(|inv| inv.entries.as_ref());
        let to_ks = label("Kustomization", &k.metadata, &k.status.as_ref().and_then(|s| s.conditions.clone()));
        if let Some(entries) = kinv {
            for e in entries {
                // Inventory id looks like: "ns_name_group_kind" or variants; we’ll just match kind and names conservatively
                // Safer: link if we find a HelmRelease object with same namespace/name
                for hr in &helmreleases {
                    if e.id.contains("helm.toolkit.fluxcd.io_HelmRelease")
                        && e.id.contains(&format!("{}_{}", hr.metadata.namespace.clone().unwrap_or_default(), hr.metadata.name))
                    {
                        let to_hr = label("HelmRelease", &hr.metadata, &hr.status.as_ref().and_then(|s| s.conditions.clone()));
                        edges.insert((to_ks.clone(), to_hr));
                    }
                }
            }
        }
    }

    // Edges: HelmRepository -> HelmRelease (via hr.spec.chart.spec.sourceRef)
    for hr in &helmreleases {
        if let Some(spec) = &hr.spec {
            if let Some(chart) = spec.pointer("/chart/spec") {
                let kind = chart.pointer("/sourceRef/kind").and_then(|x| x.as_str()).unwrap_or("");
                let name = chart.pointer("/sourceRef/name").and_then(|x| x.as_str()).unwrap_or("");
                let ns = chart.pointer("/sourceRef/namespace").and_then(|x| x.as_str()).unwrap_or("flux-system");
                if kind.eq_ignore_ascii_case("HelmRepository") {
                    if let Some(hlabel) = helm_repo_index.get(&(name.to_string(), ns.to_string())) {
                        let from = hlabel.clone();
                        let to = label("HelmRelease", &hr.metadata, &hr.status.as_ref().and_then(|s| s.conditions.clone()));
                        edges.insert((from, to));
                    }
                }
            }
        }
    }

    // Output Mermaid
    println!("```mermaid");
    println!("graph TD");
    println!();

    // Assign short ids for Mermaid
    let mut ids = BTreeMap::new();
    for (i, n) in nodes.iter().enumerate() {
        ids.insert(n.clone(), format!("N{}", i));
    }

    // Nodes
    for n in &nodes {
        let id = ids.get(n).unwrap();
        println!(r#"  {}["{}"]"#, id, n.replace('"', r#"\""#));
    }
    println!();

    // Edges
    for (from, to) in edges {
        let fid = ids.get(&from).unwrap();
        let tid = ids.get(&to).unwrap();
        println!("  {} --> {}", fid, tid);
    }

    println!("```");
    Ok(())
}
