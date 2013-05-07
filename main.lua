dofile("debug.lua")

local http = require("socket.http")

local explode = string.explode
local string = unicode.utf8

local baseurl = "http://texfragen.de"
local export = "/_export/raw/"

notthere = {
    ["formelsatz"] = true,
    ["tikz"] = true,
    ["was_ist_metafont"] = true,
    ["was_sind_virtuelle_fonts"] = true,
    ["tex_einheiten"] = true,
    ["paket_nowidow"] = true,
    ["paket_mdwlist"] = true,
    ["paket_icomma"] = true,
    ["paket_siunitx"] = true,
    ["paket_vmargin"] = true,
    ["paket_layout"] = true
}

function read_page(page)
    if notthere[page] then
        return nil
    end
    w("read page %q",tostring(page))
    local txt
    if not lfs.attributes("raw/"..page) then
        txt, b, c = http.request(baseurl .. export .. page)
        if b == 200 then
            f = io.open("raw/" .. page,"w")
            f:write(txt)
            f:close()
        end
    end
    local f,msg = io.open("raw/" .. page,"r")
    if not f then
        w(msg)
        return nil
    end
    txt = f:read("*all")
    f:close()
    return txt
end

visited = {}
pages_to_process = {"Startseite"}


function handle_section( a,b )
    local l = string.len(a)
    local section
    if l == 5 then
        section = "subsection"
    elseif l == 6 then
        section = "subsubsection"
    else
        assert(false,l)
    end
    return string.format("·\\%s{·%s·}·",section,b)
end

repl = {
 ["["] = "",
 ["]"] = "",
 ["\\"] = "",
 ["$"] = "",
 ["("] = "",
 [")"] = "",
 ["ä"] = "ae",
 ["ö"] = "oe",
 ["ü"] = "ue",
 ["ß"] = "ss",
 [" "] = "_",
 ["…"] = "",
 ["?"] = "",
 ["/"] = "_",
}
function sanitize_link( str )
    str = string.lower(str)
    str = string.gsub(str,".",repl)
    return str
end

function is_mail( str )
    if string.match(str,"@") then return true end
    return false
end

function handle_link( a )
    -- printtable("handle_link",{a,b})
    local tab = explode(a,"|")
    if string.match(tab[1],"^http") then
        return string.format("·\\href{·%s·}{·%s·}·",tab[1],tab[2] or tab[1])
    elseif is_mail(tab[1]) then
        return string.format("·\\href{·%s·}{·%s·}·",tab[1],tab[2] or tab[1])
    end
    local dest = sanitize_link(tab[1])
    pages_to_process[#pages_to_process + 1 ] = dest
    return string.format("·\\hyperref[·%s·]{·%s·}·",dest,tab[2] or tab[1])
end

function handle_verbatim( a )
    return string.format("·{\\ttfamily ·%s·}·",a)
end

function handle_it( a )
    return string.format("·{\\itshape ·%s·}·",a)
end

function handle_double_backslash()
    return "·\\\\·"
end



function process_page( pagename )
    if visited[pagename] then return end
    visited[pagename] = true

    local txt = read_page(pagename)
    if not txt then return end

    txt = string.gsub(txt,"%s*(=====+)%s*([^=]-)%s*=====+%s*",handle_section)
    txt = string.gsub(txt,"%[%[(.-)%]%]",handle_link)
    txt = string.gsub(txt,"''(.-)''",handle_verbatim)
    txt = string.gsub(txt,"//(.-)//",handle_it)
    txt = string.gsub(txt,"\\\\",handle_double_backslash)
    -- txt = string.gsub(txt,"<code latex>","·\\begin{verbatim}·")
    -- txt = string.gsub(txt,"</code>","·\\end{verbatim}·")
    txt = string.gsub(txt,"\n\n","·\\par·")
    txt = string.gsub(txt,"\n"," ")

    local start,stop,protected,active
    start,stop,protected,active = string.find(txt,"^([^·]*)·([^·]*)·")
    while start ~= nil do
        tex.sprint(-2,protected)
        tex.sprint(active)
        start,stop,protected,active = string.find(txt,"^(.-)·(.-)·",stop + 1)
    end
end


while #pages_to_process ~= 0 do
    process_page(table.remove(pages_to_process,1))
end

