#!/usr/bin/env python3
import json
import os
import sys
import traceback


def result(status, **kwargs):
    payload = {"status": status}
    payload.update(kwargs)
    print(json.dumps(payload, ensure_ascii=True, sort_keys=True))


class Obj(dict):
    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError as exc:
            raise AttributeError(name) from exc

    def __setattr__(self, name, value):
        self[name] = value

    def validate(self, *args, **kwargs):
        return True


def make_get(**kwargs):
    get = Obj()
    for key, value in kwargs.items():
        setattr(get, key, value)
    return get


def response_ok(response):
    if isinstance(response, dict):
        if response.get("siteStatus") is True or response.get("siteId"):
            return True
        if str(response.get("status")) == "0" and isinstance(response.get("message"), dict):
            message = response["message"]
            return message.get("siteStatus") is True or bool(message.get("siteId"))
    return False


def main():
    if len(sys.argv) != 6:
        result("error", message="usage: aapanel_create_site.py <site_name> <web_root> <php_version> <run_path> <remark>")
        return 2

    site_name, web_root, php_version, run_path, remark = sys.argv[1:]
    panel_dir = "/www/server/panel"
    class_dir = os.path.join(panel_dir, "class")
    class_v2_dir = os.path.join(panel_dir, "class_v2")
    public_class_dir = os.path.join(panel_dir, "class", "public")
    if not os.path.isdir(panel_dir):
        result("error", message="aaPanel panel directory is missing")
        return 2

    os.chdir(panel_dir)
    for path in (panel_dir, class_dir, class_v2_dir, public_class_dir):
        if os.path.isdir(path) and path not in sys.path:
            sys.path.insert(0, path)

    import public  # type: ignore
    from panel_site_v2 import panelSite as PanelSiteV2  # type: ignore
    import panelSite as panelSiteModule  # type: ignore

    creator = PanelSiteV2()
    site = panelSiteModule.panelSite()
    warnings = []

    def find_site():
        try:
            row = public.M("sites").where("name=?", (site_name,)).find()
            if isinstance(row, dict) and row.get("id"):
                return row
        except Exception as exc:
            warnings.append("site lookup failed: %s" % exc)
        return None

    existing = find_site()
    created = False

    if not existing:
        add_get = make_get(
            webname=json.dumps({"domain": site_name, "domainlist": [], "count": 0}),
            path=web_root,
            type_id=0,
            type="PHP",
            version=php_version,
            port="80",
            ps=remark,
            ftp="false",
            sql="false",
            codeing="utf8",
            set_ssl=0,
            force_ssl=0,
            is_create_default_file="false",
            is_clone=False,
            ssl_auto=0,
            sub_dir="",
            project_type="PHP",
        )
        response = creator.AddSite(add_get)
        created = True
        existing = find_site()
        warnings.append("AddSite response: %s" % response)
        if not response_ok(response):
            warnings.append("AddSite response did not look successful")

    if not existing:
        result("error", message="aaPanel AddSite did not create a sites table entry", warnings=warnings)
        return 1

    site_id = str(existing.get("id"))

    for label, method_name, get_obj in [
        ("SetSiteRunPath", "SetSiteRunPath", make_get(id=site_id, runPath=run_path)),
        ("SetPHPVersion", "SetPHPVersion", make_get(siteName=site_name, version=php_version, other="")),
    ]:
        method = getattr(site, method_name, None)
        if not callable(method):
            warnings.append("%s unavailable" % label)
            continue
        try:
            response = method(get_obj)
            warnings.append("%s response: %s" % (label, response))
        except Exception as exc:
            warnings.append("%s failed: %s" % (label, exc))

    result("created" if created else "exists", site_id=site_id, site_name=site_name, path=web_root, warnings=warnings)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        result("error", traceback=traceback.format_exc())
        raise
