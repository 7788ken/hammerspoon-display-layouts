#!/usr/bin/env python3
"""生成菜单栏图标：PDF 给 Hammerspoon 用（矢量，Retina 下也清晰），SVG 用来预览。

    python3 make_icons.py [--svg 预览目录]

坐标以左上角为原点、单位是 pt，画布 18x18。图标按 macOS 模板图处理：只看透明度，
颜色由系统按浅色/深色菜单栏自动套，所以这里一律画黑色，用不透明度做层次。
"""
import os
import sys

W = H = 18
K = 0.5522847498  # 用三次贝塞尔近似四分之一圆的系数


def rrect(x, y, w, h, r):
    """圆角矩形路径；r 是一个数，或 (左上, 右上, 右下, 左下)。"""
    if isinstance(r, (int, float)):
        r = (r, r, r, r)
    tl, tr, br, bl = (min(v, w / 2, h / 2) for v in r)
    p = [("M", x + tl, y), ("L", x + w - tr, y)]
    if tr:
        p.append(("C", x + w - tr + K * tr, y, x + w, y + tr - K * tr, x + w, y + tr))
    p.append(("L", x + w, y + h - br))
    if br:
        p.append(("C", x + w, y + h - br + K * br, x + w - br + K * br, y + h, x + w - br, y + h))
    p.append(("L", x + bl, y + h))
    if bl:
        p.append(("C", x + bl - K * bl, y + h, x, y + h - bl + K * bl, x, y + h - bl))
    p.append(("L", x, y + tl))
    if tl:
        p.append(("C", x, y + tl - K * tl, x + tl - K * tl, y, x + tl, y))
    p.append(("Z",))
    return p


def fill(*paths, alpha=1.0, cut=None):
    """一个填充形状。多条路径按奇偶规则填充（套在一起就是空心框）；cut 是要挖掉的区域。"""
    return {"paths": paths, "alpha": alpha, "cut": cut}


def frame(x, y, w, h, r, t):
    """空心圆角框，边粗 t；r 同 rrect。"""
    corners = (r, r, r, r) if isinstance(r, (int, float)) else r
    inner = tuple(max(v - t, 0.3) for v in corners)
    return fill(rrect(x, y, w, h, corners), rrect(x + t, y + t, w - 2 * t, h - 2 * t, inner))


# ---------------------------------------------------------------- 图标设计

def tiles():
    """分屏显示器：显示器里左边一大块、右边上下两块。"""
    return [
        frame(1, 1.5, 16, 11, 2.5, 1.5),
        fill(rrect(3.5, 4, 5.5, 6, 0.75)),
        fill(rrect(10, 4, 4.5, 2.5, 0.75)),
        fill(rrect(10, 7.5, 4.5, 2.5, 0.75), alpha=0.45),
        fill(rrect(7.75, 12, 2.5, 3, 0)),        # 支架
        fill(rrect(5, 14.5, 8, 1.5, 0.75)),      # 底座
    ]


def dual():
    """双屏：前面一台空心，后面一台淡色实心，前后之间留一道缝。"""
    fx, fy, fw, fh, fr = 0.5, 5, 11.5, 8, 2
    gap = 1.25
    return [
        fill(rrect(6.5, 1.5, 11, 8, 2), alpha=0.45,
             cut=rrect(fx - gap, fy - gap, fw + 2 * gap, fh + 2 * gap, fr + gap)),
        frame(fx, fy, fw, fh, fr, 1.4),
        fill(rrect(5.25, 12.5, 2, 2.5, 0)),      # 支架
        fill(rrect(3, 14.75, 6.5, 1.5, 0.75)),   # 底座
    ]


def layout():
    """分块布局：一整块圆角方块切成三块，右下那块淡一些。"""
    o, i = 3, 1  # 外角、内角半径
    return [
        fill(rrect(1, 2, 7.25, 14, (o, i, i, o))),
        fill(rrect(9.75, 2, 7.25, 6.25, (i, o, i, i))),
        fill(rrect(9.75, 9.75, 7.25, 6.25, (i, i, o, i)), alpha=0.45),
    ]


def desk():
    """带鱼屏 + 笔记本：上面一条宽屏（里面三个窗口），前面一台笔记本。"""
    return [
        frame(0.5, 1, 17, 7, 1.75, 1.3),
        fill(rrect(2.7, 3.2, 3.6, 2.6, 0.5)),
        fill(rrect(7.2, 3.2, 3.6, 2.6, 0.5), alpha=0.45),
        fill(rrect(11.7, 3.2, 3.6, 2.6, 0.5)),
        frame(3.5, 9.75, 11, 6, (1.25, 1.25, 0.4, 0.4), 1.3),    # 笔记本屏幕
        fill(rrect(1.5, 15.5, 15, 1.5, (0.2, 0.2, 0.75, 0.75)),  # 底座，中间一道凹口
             cut=rrect(7.25, 15.1, 3.5, 0.9, 0.45)),
    ]


DESIGNS = {"tiles": tiles, "dual": dual, "layout": layout, "desk": desk}


# ---------------------------------------------------------------- 输出

def fmt(v):
    return ("%.3f" % v).rstrip("0").rstrip(".")


def pdf_path(path):
    ops = {"M": "m", "L": "l", "C": "c"}
    out = []
    for seg in path:
        if seg[0] == "Z":
            out.append("h")
        else:
            out.append(" ".join(fmt(v) for v in seg[1:]) + " " + ops[seg[0]])
    return "\n".join(out)


def write_pdf(shapes, filename):
    alphas = sorted({s["alpha"] for s in shapes if s["alpha"] < 1})
    gs = {a: "GS%d" % i for i, a in enumerate(alphas)}
    body = ["1 0 0 -1 0 %d cm" % H, "0 g"]  # 翻转成左上角原点
    for s in shapes:
        body.append("q")
        if s["cut"]:
            body += [pdf_path(rrect(-1, -1, W + 2, H + 2, 0)), pdf_path(s["cut"]), "W* n"]
        if s["alpha"] < 1:
            body.append("/%s gs" % gs[s["alpha"]])
        body += [pdf_path(p) for p in s["paths"]]
        body.append("f*" if len(s["paths"]) > 1 else "f")
        body.append("Q")
    stream = "\n".join(body).encode()

    extg = " ".join("/%s %d 0 R" % (gs[a], 5 + i) for i, a in enumerate(alphas))
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        ("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Resources << /ExtGState << %s >> >> "
         "/Contents 4 0 R >>" % (W, H, extg)).encode(),
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
    ] + [("<< /Type /ExtGState /ca %s >>" % fmt(a)).encode() for a in alphas]

    data = bytearray(b"%PDF-1.4\n")
    offsets = []
    for n, obj in enumerate(objects, 1):
        offsets.append(len(data))
        data += b"%d 0 obj\n" % n + obj + b"\nendobj\n"
    xref = len(data)
    data += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    data += b"".join(b"%010d 00000 n \n" % off for off in offsets)
    data += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, xref)
    with open(filename, "wb") as f:
        f.write(data)


def svg_path(path):
    out = []
    for seg in path:
        out.append(seg[0] + (" " + " ".join(fmt(v) for v in seg[1:]) if len(seg) > 1 else ""))
    return " ".join(out)


def svg(shapes, uid):
    defs, parts = [], []
    for n, s in enumerate(shapes):
        d = " ".join(svg_path(p) for p in s["paths"])
        attrs = 'd="%s" fill-rule="evenodd"' % d
        if s["alpha"] < 1:
            attrs += ' fill-opacity="%s"' % fmt(s["alpha"])
        if s["cut"]:
            mid = "%s-cut%d" % (uid, n)
            defs.append('<mask id="%s"><rect x="-1" y="-1" width="%d" height="%d" fill="#fff"/>'
                        '<path d="%s" fill="#000"/></mask>' % (mid, W + 2, H + 2, svg_path(s["cut"])))
            attrs += ' mask="url(#%s)"' % mid
        parts.append("<path %s/>" % attrs)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" fill="currentColor">'
            "<defs>%s</defs>%s</svg>" % (W, H, "".join(defs), "".join(parts)))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    svg_dir = sys.argv[sys.argv.index("--svg") + 1] if "--svg" in sys.argv else None
    for name, design in DESIGNS.items():
        shapes = design()
        write_pdf(shapes, os.path.join(here, name + ".pdf"))
        if svg_dir:
            with open(os.path.join(svg_dir, name + ".svg"), "w") as f:
                f.write(svg(shapes, name))
        print("wrote", name)
