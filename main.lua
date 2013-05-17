dofile("debug.lua")
local luxor = dofile("luxor.lua")

local http = require("socket.http")

local explode = string.explode
local utfvalues = string.utfvalues
local string = unicode.utf8

local baseurl = "http://texfragen.de"
local export = "/_export/xhtml/"
local media  = "/_media/"

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

function load_image(srctag)
    imagename = string.gsub(srctag,"^/_media/","")
    if imagename == "/lib/images/smileys/fixme.gif" then
        tex.sprint(-2,"(FIXME)")
        return
    end
    local imagename_base = string.sub(imagename, 1, #imagename - 4)
    if not lfs.attributes("images/"..imagename) or lfs.attributes("images/".. imagename_base ) then
        local url = baseurl .. media .. imagename_base .. ".pdf"
        txt, b, c = http.request(url)
        if b == 200 then
            f = io.open("images/" .. imagename_base .. ".pdf","wb")
            f:write(txt)
            f:close()
        else
            url = baseurl .. media .. imagename
            txt, b, c = http.request(url)
            if b == 200 then
                f = io.open("images/" .. imagename,"wb")
                f:write(txt)
                f:close()
            end
        end
    end
    tex.sprint(string.format("\\par\\noindent\\includegraphics[width=\\maxwidth{\\textwidth}]{images/%s}\\par ",imagename_base))
end

function read_page(page)
    if notthere[page] then
        return nil
    end
    local pagename = page
    local txt
    if not lfs.attributes("raw/"..pagename) then
        local url = baseurl .. export .. pagename
        txt, b, c = http.request(url)
        if b == 200 then
            f = io.open("raw/" .. pagename,"w")
            f:write(txt)
            f:close()
        end
    end
    local f,msg = io.open("raw/" .. pagename,"r")
    if not f then
        w(msg)
        return nil
    end
    txt = f:read("*all")
    f:close()
    return txt
end



function parse_link( elt )
    if elt.class == "urlextern" or elt.class == "mail" then
        tex.sprint("\\href{")
        tex.sprint(-2, elt.href)
        tex.sprint("}{")
        tex.sprint(-2, elt[1])
        tex.sprint("}")
    elseif elt.class == "wikilink1" then
        local link = elt.title
        pages_to_process[#pages_to_process + 1 ] = link
        tex.sprint("\\hyperref[")
        tex.sprint(-2, link)
        tex.sprint("]{")
        tex.sprint(-2, elt[1])
        tex.sprint("}")
    elseif elt.class == "wikilink2" then
        tex.sprint(-2,elt[1])
    end
end

function parse_table( tbl )
    local maxcol = 0
    for i=1,#tbl do
        if type(tbl[i]) == "table" then
            local row = tbl[i]
            local col = 0
            for j=1,#row do
                local cell = row[j]
                if type(cell) == "table" then
                    col = col + 1
                end
            end
            maxcol = math.max(maxcol, col)
        end
    end
    tex.sprint("\\par\\begin{tabu}spread 0pt{" .. string.rep("X[-1]",maxcol) .. "}")
    for i=1,#tbl do
        if type(tbl[i]) == "table" then
            local row = tbl[i]
            local c = 1
            for j=1,#row do
                local cell = row[j]
                if type(cell) == "table" then
                    parse_element(cell)
                    if c < maxcol then
                        tex.sprint(" & ")
                    else
                        tex.sprint("\\strut ")
                    end
                    c = c + 1
                end
            end
        tex.sprint("\\\\")
        end
    end
    tex.sprint("\\end{tabu}\\par")
end

function to_bookmark(codepoint)
    if codepoint < 256 then
        return string.format("\\9000\\%03o",codepoint)
    elseif codepoint < 65536 then
        return string.format("\\9%03o\\%03o",codepoint / 256, codepoint % 256)
    else
        -- ignore for now
    end
end

function parse_header( tmp )
    local name = tmp[1][1]

    local bookmark = {}
    for i in utfvalues(name) do
      bookmark[#bookmark + 1] = to_bookmark(i)
    end

    local heading_type = tmp[".__name"]
    if heading_type == "h1" then
        tex.sprint("\\section{\\texorpdfstring{")
        tex.sprint(-2,name)
        tex.sprint("}{")
        tex.sprint(-2,table.concat(bookmark))
        tex.sprint("}}")
        tex.sprint("\\label{")
        tex.sprint(current_pagename)
        tex.sprint("}")
    elseif heading_type == "h2" then
        tex.sprint("\\subsection{\\texorpdfstring{")
        tex.sprint(-2,name)
        tex.sprint("}{")
        tex.sprint(-2,table.concat(bookmark))
        tex.sprint("}}")
    elseif heading_type == "h3" then
        tex.sprint("\\subsubsection{\\texorpdfstring{")
        tex.sprint(-2,name)
        tex.sprint("}{")
        tex.sprint(-2,table.concat(bookmark))
        tex.sprint("}}")
    elseif heading_type == "h4" then
        tex.sprint("\\subsubsection{\\texorpdfstring{")
        tex.sprint(-2,name)
        tex.sprint("}{")
        tex.sprint(-2,table.concat(bookmark))
        tex.sprint("}}")
    end
end

listingcounter = 0
function handle_listing( txt )
    listingcounter = listingcounter + 1
    local filename = string.format("lst/listing%d.tex",listingcounter)
    f = io.open(filename,"w")
    f:write(txt)
    f:close()
    tex.sprint(string.format("\\lstinputlisting{%s}",filename))
end

function parse_element( elt )
    local ret = {}
    for i=1,#elt do
        tmp = elt[i]
        if type(tmp) == "table" then
            local name = tmp[".__name"]
            if name == "h1" or name == "h2" or name == "h3" or name == "h4" then
                ret[#ret + 1] = parse_header(tmp)
            elseif name == "ul" then
                tex.sprint("\\begin{itemize}")
                parse_element(tmp)
                tex.sprint("\\end{itemize}")
            elseif name == "ol" then
                tex.sprint("\\begin{enumerate}")
                parse_element(tmp)
                tex.sprint("\\end{enumerate}")
            elseif name == "table" then
                ret[#ret + 1] = parse_table( tmp )
            elseif name == "li" then
                tex.sprint("\\item")
                parse_element(tmp)
            elseif name == "div" then
                if tmp.class ~= "toc" then
                    ret[#ret + 1] = parse_element( tmp )
                end
            elseif name == "img" then
                load_image(tmp.src)
            elseif name == "code" then
                tex.sprint("{\\ttfamily ")
                parse_element( tmp )
                tex.sprint("}")
            elseif name == "em" then
                tex.sprint("{\\itshape ")
                parse_element( tmp )
                tex.sprint("}")
            elseif name == "strong" then
                tex.sprint("{\\bfseries ")
                parse_element( tmp )
                tex.sprint("}")
            elseif name == "a" then
                parse_link( tmp )
            elseif name == "p" then
                parse_element( tmp )
            elseif name == "br" then
                tex.sprint("\\\\")
            elseif name == "acronym" then
                tex.sprint(-2,tmp[1])
            elseif name == "pre" then
                handle_listing(tostring(tmp))
            else
                w("name %q",name)
            end
        else
            if string.match(tmp,"^s+$") then
                tex.print(" ")
            else
                local txt = string.gsub(tmp,"\n"," ")
                tex.sprint(-2,txt)
                if string.match(txt,"%s$") then
                    tex.sprint(" ")
                end
            end
        end
    end
    return table.concat(ret)
end


function process_page( pagename )
    if visited[pagename] then return end
    visited[pagename] = true

    local txt = read_page(pagename)
    if not txt then return end
    local ret = luxor.parse_xml(txt,{htmlentities = true})
    -- find body
    local body
    local tmp
    for i=1,#ret do
        tmp = ret[i]
        if type(tmp)=="table" and tmp[".__name"] == "body" then body = tmp break end
    end

    local div_export
    for i=1,#body do
        tmp = body[i]
        if type(tmp)=="table" and tmp[".__name"] == "div" and tmp.class == "dokuwiki export" then div_export = tmp break end
    end
    current_pagename = pagename
    parse_element(div_export)
end

visited = {}
-- pages_to_process = {"was_ist_ctan"}
pages_to_process = {"Startseite"}

while #pages_to_process ~= 0 do
    process_page(table.remove(pages_to_process,1))
end

