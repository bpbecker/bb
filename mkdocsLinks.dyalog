 rpt←{walk}mkdocsLinks url;h;r;x;m;redir;t;queue;path;prot;refs;links;ids;page;beginsWith;this;intern;resolveURL;new;i;v;preconnect;mask;anchors;docs;anchor;missingAnchors;missingRefs;otherErrors;missingFiles;removeBase;missing;toUTF8;canonical;first;URLbase;allRefs;missingFile;missingIn
⍝ validate links within a mkdocs documentation site
⍝ {walk} is 1 (the default) to walk down the doc tree, or 0 to just check links on the given page

 walk←{6::⍵ ⋄ walk}1
 :If 0=⎕NC'HttpCommand' ⋄ ⎕SE.SALT.Load'HttpCommand' ⋄ {}HttpCommand.Upgrade ⋄ :EndIf
 :If 0=⎕NC'XMLUtils'
     'Could not load XMLUtils'⎕SIGNAL 22/⍨0≠⊃HttpCommand.Fix'https://github.com/bpbecker/xmlutils/Source/XMLUtils.apln'
 :EndIf

 url←{
     ∧/⍵∊⎕D:'localhost:',⍵ ⍝ just a port number
     '/'∊⍵:'/',⍨∊'https://' '.github.io/',[1.1]'/'(≠⊆⊢)⍵  ⍝ organization/repository
     'https://dyalog.github.io/',⍵,'/' ⍝ just a repo name, assumes Dyalog
 }url

 h←HttpCommand.New'get'url
 'Accept-Encoding'h.SetHeader'' ⍝ turn off accepting zipped files (it seems there's a bug in Conga)

 beginsWith←{⍵≡(≢⍵)↑⍺}
 resolveURL←{
 ⍝ ⍺-page URL
 ⍝ ⍵-URL to resolve
 ⍝ ←-resolved URL
     '#'=⊃⍵:⍵
     1=≢'^https?:\/\/'⎕S'&'⊢⍵:⍵ ⍝ exit if begins with http[s]://
     url←⍺,⍵
     (prot path)←url(↑{⍺ ⍵}↓)⍨2+⍸<\'://'⍷url
     prot,(≢⊃1 ⎕NPARTS'')↓∊1 ⎕NPARTS path
 }
 URLbase←{⍵{(⍵↑⍺),(⊢↑⍨⍳∘'/')⍵↓⍺,'/'}⊃2+⍸<\'://'⍷⍵}
 removeBase←{t←⍵↓⍨(≢⍺)×⍵ beginsWith ⍺ ⋄ (0∊⍴t)∨'/'=⊃⌽t:t,'index.html' ⋄ t}

 toUTF8←{0::⍵ ⋄ 'UTF-8'⎕UCS ⎕UCS ⍵⊣'UTF-8'⎕UCS'UTF-8'⎕UCS ⍵}

 :If ∨/'.github.io'⍷⍥⎕C url ⍝ GitHub pages published with mike redirect to an alias, we need to follow it to get the actual content.
     :Repeat
         r←h.Run
         :If ~r.IsOK ⋄ ⎕←'Unable to retrieve "',url,'": ',⍕r ⋄ →0 ⋄ :EndIf
         :If ~∨/'text/html'⍷r.GetHeader'content-type' ⋄ ⎕←'"',url,'" content-type is not text/html?? ',⍕r ⋄ →0 ⋄ :EndIf
         x←XMLUtils.HTMLtoXHTML toUTF8 r.Data
         redir←''
         :If ∨/m←x XMLUtils.Xfind'/3/meta//http-equiv/refresh'
             redir←(t←x XMLUtils.Xselect m)XMLUtils.Xattr'content'
             :If 0∊⍴redir←'url='{(≢⍺)↓⍵/⍨∨\⍺⍷⍵}∊redir ⋄ ⎕←'No redirection link found?'t ⋄ →0 ⋄ :EndIf
             h.URL,←redir
             (prot path)←h.URL(↑{⍺ ⍵}↓)⍨2+⍸<\'://'⍷h.URL
             h.URL←prot,(≢⊃1 ⎕NPARTS'')↓⊃1 ⎕NPARTS path
         :EndIf
     :Until ~∨/m
 :EndIf

 h.(BaseURL URL)←h.URL''
 links←⍬
 queue←,⊂h.URL
 ⍞←'Scanning: '
 first←1
 :While ~0∊⍴queue
     h.URL←⊃queue
     r←h.Run
     ⍞←'.'
     links,←page←⎕NS'' ⍝ links is a vector of namespaces - one for each resource examined
     page.URL←(1+first)⊃h.URL r.URL ⍝ save the URL we actually retrieved
     page.Response←⍕r ⍝ save the HttpCommand response
     page.HttpStatus←r.HttpStatus
     page.IsHTML←0
     :If page.IsOK←r.IsOK
         page.Internal←page.URL beginsWith h.BaseURL
         :If (page.Internal∧walk∨first)∨walk∧first ⍝ don't walk if walk=0 or this page isn't internal
             :If page.IsHTML←∨/'text/html'⍷r.GetHeader'content-type'
                 x←XMLUtils.HTMLtoXHTML toUTF8 r.Data
                 canonical←x XMLUtils.Xselect x XMLUtils.Xfind'//link//rel/canonical'
                 :Select ≢canonical
                 :Case 0
                     canonical←''
                 :Case 1
                     canonical←⊃canonical XMLUtils.Xattr'href'
                     page.URL←∊canonical
                     :If first
                         h.BaseURL←URLbase page.URL
                     :EndIf
                 :Else
                     ∘∘∘ ⍝ more than 1 <link rel="canonical"> element???
                 :EndSelect
                 first←0
                 refs←canonical~⍨x XMLUtils.Xattrval'////href'
                 refs,←x XMLUtils.Xattrval'////src'
                 preconnect←x XMLUtils.Xselect x XMLUtils.Xfind'//link//rel/preconnect'
                 preconnect←preconnect XMLUtils.Xattr'href'
                 refs←(∪refs)~(,'.')('..'),⊃,/preconnect ⍝ remove preconnects
                 refs←refs[1+'^(?!https:\/\/github.com\/.*\/edit\/.*\.md)'⎕S{⍵.BlockNum}⊢refs] ⍝ remove mkdocs "edit" links
                 refs/⍨←~refs beginsWith¨⊂'data:' ⍝ remove inline image data refs
                 page.ids←x XMLUtils.Xattrval'////id'
                 page.refsFound←(≢refs)⍴¯1 ⍝ make refs for searching - ¯1=not searched, 0=not found, 1=found
                 this←'#'=⊃¨refs ⍝ internal refs to anchors in this page
                 (this/page.refsFound)←(1↓¨this/refs)∊(⊂''),page.ids ⍝ mark internal refs that match ids in this page
                 ((~this)/refs)←new←page.URL∘resolveURL¨(~this)/refs
                 page.refs←refs
                 queue,←∪({⍵↑⍨¯1+⍵⍳'#'}¨new)~queue,links.URL
             :EndIf
         :EndIf
     :EndIf
     queue↓⍨←1
 :EndWhile
 ⎕←'Done!'

⍝ missingFiles←links.URL/⍨404≡¨links.HttpStatus ⍝ files not found (404 HTTP status)
⍝ missingIn←''
⍝ allRefs←links ⎕VGET⊂'refs' ''
⍝ :For missingFile :In missingFiles
⍝     missingIn,←⊂⍪(∊(⊂⊂missingFile)∊¨allRefs)/links.URL ⍝ files with references to missing files
⍝ :EndFor

 otherErrors←links.URL/⍨~links.HttpStatus∊200 404 ⍝ mark any files that had other HTTP status than 200 or 404

 missingAnchors←missingRefs←0 2⍴⊂''
 :For page :In links/⍨links.IsHTML ⍝ only track links in HTML files
     v←⍸page.refsFound=¯1          ⍝ mark references to check
     anchors←page.refs[v]⍳¨'#'     ⍝ mark anchor position, if any, in references
     docs←links.URL⍳(¯1+anchors)↑¨page.refs[v] ⍝ extract the file name from the ref and look it up in the files we've examined
     m←(≢links)≥docs               ⍝ mark links that we have a page URL for
     (page.refsFound[m/v])←200=links[m/docs].HttpStatus ⍝ and see if file actually exists
     missing←⍬
     :For i :In ⍸anchors<≢¨page.refs[v] ⍝ now check that anchors exist in the target pages
         :If links[docs[i]].IsHTML ⍝ only follow links in HTML files (e.g. not .pdf)
             anchor←⊂anchors[i]↓i⊃page.refs[v] ⍝ take the anchor name (id in the target file)
             :If ~anchor∊links[docs[i]].ids ⍝ does that id exist in the target file?
                 missing,←⊂h.BaseURL removeBase i⊃page.refs[v] ⍝ if not, add it to the missing list
             :EndIf
         :EndIf
     :EndFor
     :If ~0∊⍴missing
         missingAnchors⍪←page.URL(↑missing) ⍝ refs to a missing anchors in the target pages
     :EndIf
     :If ∨/mask←1≠page.refsFound ⍝ are there any references that we couldn't examine?
         missingRefs⍪←page.URL(↑h.BaseURL∘removeBase¨mask/page.refs) ⍝ report any references not found
     :EndIf
 :EndFor
⍝ missingFiles←h.BaseURL∘removeBase¨missingFiles
⍝ missingIn←h.BaseURL∘removeBase¨¨missingIn
 missingRefs←h.BaseURL∘removeBase¨missingRefs
 missingAnchors←h.BaseURL∘removeBase¨missingAnchors
 otherErrors←h.BaseURL∘removeBase¨otherErrors
 rpt←0 2⍴⊂''
⍝ rpt←'Missing Files' 'Referenced In'⍪missingFiles,[1.1]missingIn
 rpt⍪←'Missing Refs' 'Referenced In'⍪⌽missingRefs
 rpt⍪←'' ''
 rpt⍪←'Missing Anchors' 'Referenced In'⍪⌽missingAnchors
 rpt⍪←'' ''
 rpt⍪←'Non 200/404 Errors'(↑otherErrors)
