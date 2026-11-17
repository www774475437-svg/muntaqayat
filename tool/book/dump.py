import pypdf,sys,json
r=pypdf.PdfReader(sys.argv[1])
out=[]
for pi,p in enumerate(r.pages):
    parts=[]
    def v(text,cm,tm,fd,fs,parts=parts):
        if text and text.strip():
            name=fd.get('/BaseFont','') if fd else ''
            parts.append(dict(y=round(float(tm[5]),1),x=round(float(tm[4]),1),f=str(name),s=round(float(fs),1),t=text))
    p.extract_text(visitor_text=v)
    out.append(parts)
json.dump(out,open('chunks.json','w'),ensure_ascii=False)
