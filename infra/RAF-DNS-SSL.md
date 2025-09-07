# Export DNS – `logo-solutions.fr`

Ci-dessous, l’export de zone tel que fourni.  
Vous pouvez télécharger ce fichier en cliquant sur le lien ci‑dessous.

---

```txt
;; 
;; Domain:     logo-solutions.fr.
;; Exported:   2025-09-07 13:33:39
;;
;; This file is intended for use for informational and archival
;; purposes ONLY and MUST be edited before use on a production
;; DNS server.  In particular, you must:
;;   -- update the SOA record with the correct authoritative name server
;;   -- update the SOA record with the contact e-mail address information
;;   -- update the NS record(s) with the authoritative name servers for this domain.
;;
;; For further information, please consult the BIND documentation
;; located on the following website:
;;
;; http://www.isc.org/
;;
;; And RFC 1035:
;;
;; http://www.ietf.org/rfc/rfc1035.txt
;;
;; Please note that we do NOT offer technical support for any use
;; of this zone data, the BIND name server, or any other third-party
;; DNS software.
;;
;; Use at your own risk.
;; SOA Record
logo-solutions.fr	3600	IN	SOA	amos.ns.cloudflare.com. dns.cloudflare.com. 2050891861 10000 2400 604800 3600

;; NS Records
logo-solutions.fr.	86400	IN	NS	amos.ns.cloudflare.com.
logo-solutions.fr.	86400	IN	NS	gemma.ns.cloudflare.com.

;; A Records
ftp.logo-solutions.fr.	1	IN	A	194.164.74.58 ; cf_tags=cf-proxied:true
logo-solutions.fr.	1	IN	A	91.98.16.184 ; cf_tags=cf-proxied:false
nudger.logo-solutions.fr.	1	IN	A	91.98.16.184 ; cf_tags=cf-proxied:false
whoami.logo-solutions.fr.	1	IN	A	91.98.16.184 ; cf_tags=cf-proxied:false

;; AAAA Records
logo-solutions.fr.	1	IN	AAAA	2a02:4780:4a:6f1e:3afb:3b8e:cc15:eb4b ; cf_tags=cf-proxied:false
logo-solutions.fr.	1	IN	AAAA	2a02:4780:4c:6cf5:9989:262d:8d19:2e04 ; cf_tags=cf-proxied:false

;; CAA Records
logo-solutions.fr.	1	IN	CAA	0 issue "comodoca.com"
logo-solutions.fr.	1	IN	CAA	0 issue "letsencrypt.org"
logo-solutions.fr.	1	IN	CAA	0 issue "sectigo.com"
logo-solutions.fr.	1	IN	CAA	0 issuewild "sectigo.com"
logo-solutions.fr.	1	IN	CAA	0 issuewild "globalsign.com"
logo-solutions.fr.	1	IN	CAA	0 issuewild "comodoca.com"
logo-solutions.fr.	1	IN	CAA	0 issuewild "digicert.com"
logo-solutions.fr.	1	IN	CAA	0 issue "pki.goog"
logo-solutions.fr.	1	IN	CAA	0 issue "digicert.com"
logo-solutions.fr.	1	IN	CAA	0 issuewild "letsencrypt.org"
logo-solutions.fr.	1	IN	CAA	0 issuewild "pki.goog"
logo-solutions.fr.	1	IN	CAA	0 issue "globalsign.com"

;; CNAME Records
autoconfig.logo-solutions.fr.	1	IN	CNAME	autoconfig.mail.hostinger.com. ; cf_tags=cf-proxied:true
autodiscover.logo-solutions.fr.	1	IN	CNAME	autodiscover.mail.hostinger.com. ; cf_tags=cf-proxied:true
grafana.nudger.logo-solutions.fr.	1	IN	CNAME	nudger.logo-solutions.fr. ; cf_tags=cf-proxied:false
hostingermail-a._domainkey.logo-solutions.fr.	1	IN	CNAME	hostingermail-a.dkim.mail.hostinger.com. ; cf_tags=cf-proxied:true
hostingermail-b._domainkey.logo-solutions.fr.	1	IN	CNAME	hostingermail-b.dkim.mail.hostinger.com. ; cf_tags=cf-proxied:true
hostingermail-c._domainkey.logo-solutions.fr.	1	IN	CNAME	hostingermail-c.dkim.mail.hostinger.com. ; cf_tags=cf-proxied:true
www.logo-solutions.fr.	1	IN	CNAME	www.logo-solutions.fr.cdn.hstgr.net. ; cf_tags=cf-proxied:true

;; MX Records
logo-solutions.fr.	1	IN	MX	5 mx1.hostinger.com.
logo-solutions.fr.	1	IN	MX	10 mx2.hostinger.com.

;; NS Records
logo-solutions.fr.	1	IN	NS	ns1.dns-parking.com.
logo-solutions.fr.	1	IN	NS	ns2.dns-parking.com.
nudger.logo-solutions.fr.	1	IN	NS	ns2.cloudflare.com.
nudger.logo-solutions.fr.	1	IN	NS	ns1.cloudflare.com.

;; TXT Records
_dmarc.logo-solutions.fr.	1	IN	TXT	"v=DMARC1; p=none"
logo-solutions.fr.	1	IN	TXT	"v=spf1 include:_spf.mail.hostinger.com ~all"
```

