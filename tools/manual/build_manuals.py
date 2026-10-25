"""Build bilingual user manuals. Run from any directory; requires reportlab."""
from pathlib import Path
import re
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted, KeepTogether
from package_metadata import ROOT, VERSION

OUT = ROOT / "docs" / "manual"
NAVY, TEAL, INK = colors.HexColor("#122A3A"), colors.HexColor("#087C80"), colors.HexColor("#243746")


def register_fonts():
    locations = [
        (Path("C:/Windows/Fonts"), ("segoeui.ttf", "segoeuib.ttf", "segoeuii.ttf", "consola.ttf")),
        (Path("/usr/share/fonts/truetype/dejavu"), ("DejaVuSans.ttf", "DejaVuSans-Bold.ttf", "DejaVuSans-Oblique.ttf", "DejaVuSansMono.ttf")),
    ]
    for folder, names in locations:
        if all((folder / n).is_file() for n in names):
            for alias, name in zip(("Body", "Body-Bold", "Body-Italic", "Code"), names):
                pdfmetrics.registerFont(TTFont(alias, str(folder / name)))
            pdfmetrics.registerFontFamily("Body", normal="Body", bold="Body-Bold", italic="Body-Italic", boldItalic="Body-Bold")
            return
    raise RuntimeError("Install Segoe UI/Consolas or DejaVu Sans/Mono fonts before building the manuals.")


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, language="es", **kwargs):
        super().__init__(*args, **kwargs)
        self.saved_pages, self.language = [], language

    def showPage(self):
        self.saved_pages.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        count = len(self.saved_pages)
        for state in self.saved_pages:
            self.__dict__.update(state)
            w, h = A4
            self.setFillColor(NAVY)
            self.rect(0, h - 43, w, 43, fill=1, stroke=0)
            self.setFillColor(colors.white)
            self.setFont("Body-Bold", 10)
            self.drawString(48, h - 27, f"rcodeagent {VERSION}")
            self.setFont("Body", 9)
            self.drawRightString(w - 48, h - 27, "Manual de uso" if self.language == "es" else "User manual")
            self.setStrokeColor(colors.HexColor("#C8D9DE"))
            self.line(48, 43, w - 48, 43)
            self.setFillColor(INK)
            self.setFont("Body", 8)
            self.drawString(48, 29, f"José Gamarra-Moncayo | {VERSION}")
            self.drawRightString(w - 48, 29, f"{self._pageNumber} / {count}")
            super().showPage()
        super().save()


def inline(text):
    text = escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"(https://[^\s]+)", r'<link href="\1" color="#087C80">\1</link>', text)
    return text


def build(language):
    target = OUT / f"rcodeagent-{VERSION}-Manual-{language.upper()}.pdf"
    document = SimpleDocTemplate(str(target), pagesize=A4, rightMargin=48, leftMargin=48,
        topMargin=66, bottomMargin=60, title=f"rcodeagent {VERSION} - {'Manual de uso' if language == 'es' else 'User manual'}",
        author="José Gamarra-Moncayo", subject="Installation, permissions, Viewer recovery and practical examples")
    body = ParagraphStyle("body", fontName="Body", fontSize=10.1, leading=14.2, textColor=INK, spaceAfter=9,
        splitLongWords=True, allowWidows=0, allowOrphans=0, alignment=TA_LEFT)
    title = ParagraphStyle("title", parent=body, fontName="Body-Bold", fontSize=36, leading=42,
        textColor=NAVY, spaceBefore=48, spaceAfter=28)
    chapter = ParagraphStyle("chapter", parent=body, fontName="Body-Bold", fontSize=21, leading=27,
        textColor=TEAL, spaceAfter=22, keepWithNext=True)
    sub = ParagraphStyle("sub", parent=body, fontName="Body-Bold", fontSize=12, leading=17,
        textColor=NAVY, spaceBefore=5, spaceAfter=9, keepWithNext=True)
    bullet = ParagraphStyle("bullet", parent=body, leftIndent=12, firstLineIndent=-9, spaceAfter=6)
    code = ParagraphStyle("code", fontName="Code", fontSize=8.4, leading=12, textColor=NAVY,
        backColor=colors.HexColor("#EFF5F7"), borderPadding=10, spaceBefore=5, spaceAfter=16)
    story, paragraph, code_lines, in_code = [], [], [], False

    def flush():
        if paragraph:
            story.append(Paragraph(inline(" ".join(paragraph)), body))
            paragraph.clear()

    for line in (OUT / f"manual-{language}.md").read_text(encoding="utf-8").splitlines():
        if line.startswith("```"):
            flush()
            if in_code:
                for value in code_lines:
                    if pdfmetrics.stringWidth(value, "Code", code.fontSize) > A4[0] - 116:
                        raise ValueError(f"Code line too wide: {value}")
                story.append(Preformatted("\n".join(code_lines), code))
                code_lines.clear()
            in_code = not in_code
        elif in_code:
            code_lines.append(line)
        elif line.startswith("## "):
            flush()
            story.extend([PageBreak(), Paragraph(inline(line[3:]), chapter)])
        elif line.startswith("# "):
            flush()
            story.append(Paragraph(inline(line[2:]), title))
        elif line.startswith("### "):
            flush()
            story.append(Paragraph(inline(line[4:]), sub))
        elif line.startswith("- ") or re.match(r"^\d+[.] ", line):
            flush()
            text = "• " + line[2:] if line.startswith("- ") else line
            story.append(Paragraph(inline(text), bullet))
        elif not line.strip():
            flush()
        else:
            paragraph.append(line)
    flush()
    document.build(story, canvasmaker=lambda *args, **kwargs: NumberedCanvas(*args, language=language, **kwargs))
    print(target)


if __name__ == "__main__":
    register_fonts()
    for language in ("es", "en"):
        build(language)
