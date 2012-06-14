"=============================================
"    Name: fold.vim
"    File: fold.vim
"  Author: Rykka G.Forest
"  Update: 2012-06-14
" Version: 0.5
"=============================================
let s:cpo_save = &cpo
set cpo-=C


let s:p = g:_riv_p

fun! s:init_stat() "{{{
    let len = line('$')
    let b:foldlevel = g:riv_fold_level
    if len > g:riv_auto_fold1_lines && g:riv_auto_fold_force == 1
        let b:foldlevel = b:foldlevel >= 1 ? 1 : 0 
    elseif len > g:riv_auto_fold2_lines && g:riv_auto_fold_force == 1
        let b:foldlevel = b:foldlevel >= 2 ? 2 : 0 
    endif
    if !exists("b:fdl_list") 
        call s:parse_from_start()
    elseif len(b:fdl_list) != line('$')+1
        call s:parse_from_start()
        " for i in range(1,line('$'))
        "     if b:lines[i] != getline(i)
        "         call s:parse_from_row(i)
        "         break
        "     endif
        " endfor
    endif
endfun "}}}
fun! s:parse_from_start() "{{{
    redraw
    echo "Parsing buf ..."
    let len = line('$')
    let b:state = { 'l_chk':[], 
                \'matcher':[], 'sectmatcher':[], 
                \'s_root': { 'parent': 'None'  , 'child':[] ,
                \  'bgn': 'sect_root'} ,
                \'l_root': { 'parent': 'None'  , 'child':[] ,
                \ 'bgn': 'list_root'} ,
                \  'None': { 'parent': 'None'  , 'child':[] ,
                \ 'bgn': 'None'} ,
                \}
    let b:obj_dict = {'sect_root':b:state.s_root, 
                \ 'list_root':b:state.l_root,
                \ 'None': b:state.None }
    " 3%
    let b:fdl_list = map(range(len+1),'0')
    let b:lines= ['']+getline(1,line('$'))+['']
    for i in range(len+1)
    " 75%
        call s:check(i)
    endfor
    " 20%
    call sort(b:state.matcher,"s:sort_match")
    call s:set_fdl_dict()
    call s:set_sect_end()
    call s:set_fdl_list()
    call s:set_td_child(b:state.l_root)
    call garbagecollect(1)
    echon "Done"
    redraw
endfun "}}}
fun! s:parse_from_row(row) "{{{
    " seems it's buggy.
    call filter(b:obj_dict,      'v:key < a:row')
    call filter(b:state.matcher, 'v:val.bgn < a:row')
    call filter(b:state.sectmatcher, 'v:val.bgn < a:row')
    call filter(b:state.s_root.child,  'v:val < a:row')
    call filter(b:state.l_root.child,  'v:val < a:row')
    if line('$')+1-len(b:fdl_list) > 0
        call extend(b:fdl_list,range(line('$')+1-len(b:fdl_list)))
    endif
    let  b:fdl_list[a:row : ] = map(b:fdl_list[a:row : ],'0')
    let b:lines= ['']+getline(1,line('$'))+['']
    let b:state.l_chk = []
    for i in range(a:row, line('$'))
        call s:check(i)
    endfor
    " 20%
    " sort the unordered list.
    call sort(b:state.matcher,"s:sort_match")
    call s:set_fdl_dict()
    call s:set_sect_end()
    call s:set_fdl_list()
    call s:set_td_child(b:state.l_root)
endfun "}}}
let s:sect_sep = g:_riv_t.sect_sep
fun! s:set_fdl_dict() "{{{
    
    let stat = b:state
    let mat = stat.matcher

    let sec_punc_list = []      " the punctuation list used by section

    let p_s_obj = stat.s_root   " previous section object, init with root
    let sec_lv = 0              " the section level calced by punc_list
    let p_sec_lv = sec_lv       

    let lst_lv = 0              " current list_level
    let p_lst_lv = 0
    let p_l_obj = stat.l_root   " previous list object 
    let p_lst_end = line('$')   " let  root contains all level 1 list object
    for m in mat
        let f = 0
        if m.type == 'sect'
            " Sect Part "{{{
            let level = index(sec_punc_list,m.attr)+1
            if level == 0
                call add(sec_punc_list,m.attr)
                let level = len(sec_punc_list)
            endif
            let lst_lv = 0
            let sec_lv = level
            let m.level = level
            

            " Add child and parent to document object.
            if sec_lv > p_sec_lv
                let sec_num = 1
                let m.sec_num = sec_num
                call s:add_child(p_s_obj,m)
            elseif sec_lv == p_sec_lv
                let sec_num = p_sec_num + 1
                let m.sec_num =sec_num
                call s:add_brother(p_s_obj,m)
            elseif sec_lv < p_sec_lv 
                " create the next older of last item.
                for i in range(p_sec_lv - sec_lv+1)
                    if p_s_obj.bgn == 'sect_root'
                        break
                    endif
                    let p_s_obj = s:get_parent(p_s_obj)
                endfor
                let brother = s:get_child(p_s_obj,-1)
                let sec_num = brother.sec_num+1
                let m.sec_num = sec_num
                call s:add_brother(brother, m)
            endif

            let p_s_obj = m
            let p_sec_lv = sec_lv
            let p_sec_num = sec_num
            
            " Get the section text like 1.1 1.2 1.2.1
            let t_obj = m
            let t_lst = []
            while !empty(t_obj) && t_obj.bgn != 'sect_root'
                call add(t_lst, t_obj['sec_num'])
                let t_obj = s:get_parent(t_obj)
            endwhile
            let m.txt = join(reverse(t_lst), s:sect_sep)

            let b:obj_dict[m.bgn]   = m
            let b:obj_dict[m.bgn+1] = m
            if m['title_rows'] == 3
                let b:obj_dict[m.bgn+2] = m
            endif
            " Stop Sect Part "}}}
        elseif m.type== 'list'
            " The List Part "{{{

            let lst_lv = m.level
            let lst_end = m.end

            if lst_lv > p_lst_lv
                call s:add_child(p_l_obj,m)
            elseif lst_lv == p_lst_lv  
                call s:add_brother(p_l_obj,m)
            elseif lst_lv < p_lst_lv 
                " create the next older
                for i in range(p_lst_lv - lst_lv + 1)
                    if p_l_obj.bgn == 'list_root'
                        break
                    endif
                    let p_l_obj = s:get_parent(p_l_obj)
                endfor
                let brother = s:get_child(p_l_obj,-1)
                call s:add_brother(brother, m)
            endif

            let m.td_stat = riv#list#get_td_stat(b:lines[m.bgn])

            let p_l_obj = m
            let p_lst_lv = lst_lv
            let p_lst_end = lst_end
                
            let b:obj_dict[m.bgn] = m
            " Stop List Part "}}}
        elseif m.type == 'trans'
            " stop current sect_lv
            " may encounter erros
            let lst_lv = 0
            let sec_lv = sec_lv>1 ? sec_lv-1 : 0
            let m.level = sec_lv
            let b:obj_dict[m.bgn] = m
        elseif m.type== 'exp'
            let f = 1
            let b:obj_dict[m.bgn] = m
        elseif m.type == 'block'
            let f = 1
            let b:obj_dict[m.bgn] = m
        elseif m.type == 'table'
            let f = 1
            let m.col = len(split(b:lines[m.bgn], '+',1)) - 2
            let m.row = len(filter(b:lines[m.bgn:m.end], 
                        \'v:val=~''^\s*+''')) - 1
            let b:obj_dict[m.bgn] = m
        endif
        
        let m.fdl = sec_lv+lst_lv+f

    endfor
    
endfun "}}}
fun! s:set_sect_end() "{{{
    let stat = b:state
    let smat = stat.sectmatcher
    for i in range(len(smat))
        let m = smat[i]
        let bgn = m.bgn
        let fdl = m.fdl
        
        " We should parse section level by level.
        " 1~2 ~3 
        "  ^1
        " 1.1~1.2~1.3 ~ 2
        "    ^:2      ^: should be level 1  
        " 1.1.1~1.1.2
        "      ^:3
        " if have brother, then to next brother
        " else parent's brother's bgn
        "
        let n_b = riv#fold#get_next_brother(m)
        let n_p = s:get_parent(m)
        while empty(n_b)
            if (n_p.bgn == 'sect_root' )
                break
            endif 
            let n_b = riv#fold#get_next_brother(n_p)
            let n_p = s:get_parent(n_p)
        endwhile
        if empty(n_b)
            let n_b = {'level':0,'bgn':line('$')}
        endif
        
        if m.level > n_b.level && g:riv_fold_blank ==0
            let m.end = prevnonblank(n_b.bgn-1)+1
        elseif m.level > n_b.level && g:riv_fold_blank == 1
            let m.end = n_b.bgn-2
        else
            let m.end = n_b.bgn-1
        endif

    endfor
endfun "}}}
fun! s:set_fdl_list() "{{{
    let stat = b:state
    let mat = stat.matcher

    " fold_blank: 0,1,2 (default:0)
    " 0     fold one blank line at the most
    " 1     fold all but one blank line
    " 2     fold all blank line
    for m in mat
        let bgn = m.bgn
        let fdl = m.fdl
        let end = m.end             " all should have end now
        if g:riv_fold_blank ==1 && b:lines[end] =~ '^\s*$'
            let end = end - 1
        elseif g:riv_fold_blank==0 && b:lines[end] =~ '^\s*$'
            let end = prevnonblank(end) + 1
        endif
        let  b:fdl_list[bgn : bgn] = map(b:fdl_list[bgn : bgn],'">".fdl')
        if bgn+1 <= end
            let b:fdl_list[bgn+1 : end] = map(b:fdl_list[bgn+1 : end],'fdl')
        endif
    endfor
endfun "}}}

fun! s:check(row) "{{{
    " check and set the state and return the value dict.
    let row = a:row
    let line = b:lines[row]
                
    if b:foldlevel > 0
        call s:s_checker(row)
    endif

    if b:foldlevel > 2
        call s:t_checker(row)
    endif
    
    if line=~'^\s*$' && row != line('$')
        return
    endif

    if b:foldlevel > 1
        call s:l_checker(row)
    endif

    if b:foldlevel > 2
        call s:e_checker(row)
        call s:b_checker(row)

        if !has_key(b:state, 'e_chk') && !has_key(b:state, 'b_chk')  
            \ && line=~s:p.literal_block && b:lines[a:row+1]=~ '^\s*$'
            if line=~s:p.exp_m
                let b:state.e_chk= {'type': 'exp', 'bgn':a:row,}
                return 1
            else
                let b:state.b_chk = {'type': 'block', 'bgn': a:row+1, 
                            \ 'indent': riv#fold#indent(line)}
            endif
        endif

    endif

    if line=~'^\s*[[:alnum:]]\+\_s'
        return
    elseif b:foldlevel > 1 && !has_key(b:state, 'e_chk')
                \ && line=~s:p.list_all             
        let idt = riv#fold#indent(line)
        call insert(b:state.l_chk, 
                    \ {'type': 'list', 'bgn': a:row, 
                    \ 'indent': idt,
                    \ 'child': [], 'parent': 'list_root',
                    \ 'level': idt/2+1,
                    \},0)
        return 1
    elseif b:foldlevel > 0 && line=~s:p.section 
                \ && line !~ '^\.\.\_s*$'
        let b:state.s_chk =  {'type': 'sect' , 'bgn': a:row, 'attr': line[0]}
        return 1
    elseif line=~'^\s*\w'
        return
    elseif b:foldlevel > 2 && line=~s:p.exp_m
        if  (line=~'^\.\.\s*$' && a:row!=line('$') 
                            \ && b:lines[a:row+1]=~'^\s*$')
            call add(b:state.matcher,{'type': 'exp', 'mark': 'ignored', 
                    \ 'bgn': a:row, 'end': a:row})
        else
            let b:state.e_chk= {'type': 'exp', 'bgn':a:row,}
        endif
        return 1
    elseif b:foldlevel > 2 && !has_key(b:state, 't_chk') 
                \ && line=~s:p.table
        let b:state.t_chk= {'type': 'table' , 'bgn': a:row}
        return 1
    elseif b:foldlevel > 2 && line=~'^'
        call add(b:state.matcher,{'type':'trans', 'bgn':a:row,'end':a:row})
        return 1
    endif

endfun "}}}

fun! s:s_checker(row) "{{{
    if !has_key(b:state, 's_chk') | return | endif
    let chk = b:state.s_chk
    if a:row == chk.bgn+1
        let line = b:lines[a:row]
        let blank = '^\s*$'
        if line !~ blank  && b:lines[a:row-2] =~ blank  && a:row!=line('$')
            \ && b:lines[a:row+1] == b:lines[a:row-1]
            " 3 row title : blank ,section , noblank(cur) , section
            " let m = {'type':'sect', 'bgn':a:row-1,'attr':b:state.s_chk.attr,
            "             \'title_rows':3,'child':[],'parent':{}}
            let chk.bgn = a:row-1
            let chk.title_rows = 3
            let chk.child = []
            let chk.parent = 'sect_root'
            call add(b:state.matcher, chk)
            call add(b:state.sectmatcher, chk)
        elseif line =~ blank && b:lines[a:row-2]=~ blank && len(b:lines[a:row-1])>=4
            " transition : blank, section ,blank(cur) ,len>4
            " let m = {'type':'trans', 'bgn':a:row-1, 'end':a:row-1}
            let chk.type = 'trans'
            let chk.bgn = a:row - 1
            let chk.end = a:row - 1
            call add(b:state.matcher, chk)
        elseif b:lines[a:row-2] !~ blank && b:lines[a:row-3] =~ blank
                    \ && b:lines[a:row-1] != b:lines[a:row-2]
            " 2 row title : blank , noblank , section , cur
            " let m = {'type':'sect', 'bgn':a:row-2,'attr':b:state.s_chk.attr,
            "             \'title_rows':2,'child':[],'parent':{}}
            let chk.bgn = a:row - 2
            let chk.title_rows = 2
            let chk.child = []
            let chk.parent = 'sect_root'
            call add(b:state.matcher, chk)
            call add(b:state.sectmatcher, chk)
        endif
        call remove(b:state, 's_chk')
    endif
endfun "}}}
fun! s:l_checker(row) "{{{
    " a list contain all lists.
    " the final order should be sorted.
    if empty(b:state.l_chk) | return | endif
    " List can contain Explicit Markup items.
    if has_key(b:state, 'e_chk') | return | endif
    let l = b:state.l_chk
    while !empty(l)
        if (a:row>l[0].bgn && riv#fold#indent(b:lines[a:row]) <= l[0].indent ) 
                    \ && b:lines[a:row] !~ s:p.exp_m

            let l[0].end = a:row-1
            call add(b:state.matcher,l[0])
            call remove(l , 0)
        elseif a:row==line('$')
            let l[0].end = a:row
            call add(b:state.matcher,l[0])
            call remove(l , 0)
        else
            break
        endif
    endwhile
endfun "}}}
fun! s:e_checker(row) "{{{
    if !has_key(b:state, 'e_chk') | return | endif
    let chk = b:state.e_chk
    if ( b:state.e_chk.bgn < a:row && b:lines[a:row] =~ '^\S' )
        let chk.end = a:row-1
        call add(b:state.matcher,chk)
        call remove(b:state, 'e_chk')
    elseif  a:row==line('$')
        let chk.end = a:row
        call add(b:state.matcher,chk)
        call remove(b:state, 'e_chk')
    endif
endfun "}}}
fun! s:b_checker(row) "{{{
    if !has_key(b:state, 'b_chk') | return | endif
    " let chk = b:state.b_chk
    if ( b:state.b_chk.bgn < a:row && riv#fold#indent(b:lines[a:row]) <= b:state.b_chk.indent )
        let b:state.b_chk.end = a:row-1
        call add(b:state.matcher, b:state.b_chk)
        call remove(b:state, 'b_chk')
    elseif a:row==line('$') && b:state.b_chk.row < a:row
        let b:state.b_chk.end = a:row
        call add(b:state.matcher, b:state.b_chk)
        call remove(b:state, 'b_chk')
    endif
endfun "}}}
fun! s:t_checker(row) "{{{
    if !has_key(b:state, 't_chk') | return | endif
    if (b:state.t_chk.bgn < a:row && b:lines[a:row] !~ s:p.table )
        let b:state.t_chk.end = a:row-1
        call add(b:state.matcher, b:state.t_chk)
        call remove(b:state, 't_chk')
    elseif a:row==line('$')
        let b:state.t_chk.end = a:row
        call add(b:state.matcher, b:state.t_chk)
        call remove(b:state, 't_chk')
        " let b:state.t_chk={}
    endif
endfun "}}}

fun! s:add_child(p,o) "{{{
    call add(a:p.child, a:o.bgn )
    let a:o.parent = a:p.bgn
endfun "}}}
fun! s:add_brother(b,o) "{{{
    let a:o.parent = a:b.parent
    call add(b:obj_dict[a:o.parent].child, a:o.bgn )
endfun "}}}
fun! s:get_child(o,i) "{{{
    return b:obj_dict[a:o.child[a:i]]
endfun "}}}
fun! s:get_parent(o) "{{{
    return b:obj_dict[a:o.parent]
endfun "}}}
fun! riv#fold#get_prev_brother(o) "{{{
    for i in range(len(b:obj_dict[a:o.parent].child))
        if b:obj_dict[a:o.parent].child[i] == a:o.bgn
            if exists("b:obj_dict[a:o.parent].child[i-1]") && i != 0
                return b:obj_dict[b:obj_dict[a:o.parent].child[i-1]]
            endif
        endif
    endfor
    return {}
endfun "}}}
fun! riv#fold#get_next_brother(o) "{{{
    for i in range(len(b:obj_dict[a:o.parent].child))
        if b:obj_dict[a:o.parent].child[i] == a:o.bgn
            if exists("b:obj_dict[a:o.parent].child[i+1]")
                return b:obj_dict[b:obj_dict[a:o.parent].child[i+1]]
            endif
        endif
    endfor
    return {}
endfun "}}}
fun! riv#fold#get_next_older(o) "{{{
    " try to get the next item of the same level. 
    " if not find. use it's parent's next item.
    let n_b = riv#fold#get_next_brother(a:o)
    let n_p = s:get_parent(a:o)
    while empty(n_b)
        if (n_p.bgn == 'sect_root' || n_p.bgn== 'list_root')
            break
        endif 
        let n_b = riv#fold#get_next_brother(n_p)
        let n_p = s:get_parent(n_p)
    endwhile
    return n_b
endfun "}}}


fun! s:set_td_child(o) "{{{
    " Get All child's td_stat recursively
    " and update the td_child attr.
    let c_td = 0
    let len = 0
    for chd in a:o.child
        if empty(b:obj_dict[chd].child)
            if b:obj_dict[chd].td_stat != -1
                let c_td += b:obj_dict[chd].td_stat
                let len +=1
            endif
        else
            let d = s:set_td_child(b:obj_dict[chd])
            if d > 0
                let c_td += d
                let len +=1
            endif
        endif
    endfor
    if len !=0
        let c_td = (c_td+0.0)/len
        let a:o['td_child'] = c_td
    else
        let c_td = 0
    endif
    return c_td
endfun "}}}

fun! s:sort_match(i1,i2) "{{{
    return a:i1.bgn - a:i2.bgn
endfun "}}}
fun! riv#fold#indent(line) "{{{
    return strdisplaywidth(matchstr(a:line,'^\s*'))
endfun "}}}

fun! riv#fold#expr(row) "{{{
    if a:row == 1
        call s:init_stat()
    endif
    return b:fdl_list[a:row]
endfun "}}}
fun! riv#fold#text() "{{{
    let lnum = v:foldstart
    let line = b:lines[lnum]
    let cate = "    "
    if has_key(b:obj_dict,lnum)
        if b:obj_dict[lnum].type == 'sect'
            let cate = " ".b:obj_dict[lnum].txt
            if b:obj_dict[lnum].title_rows == 3
                let line = b:lines[lnum+1]
            endif
        elseif b:obj_dict[lnum].type == 'list'
            if exists("b:obj_dict[lnum].td_child")
                let td = 100 * b:obj_dict[lnum].td_child
                let cate = printf(" %3.0f%%",td)
            elseif b:obj_dict[lnum].td_stat != -1
                let td = 100 * b:obj_dict[lnum].td_stat
                let cate = printf(" %3.0f%%",td)
            endif
        elseif b:obj_dict[lnum].type == 'table'
            let cate = " " . b:obj_dict[lnum].row 
                        \  . 'x' . b:obj_dict[lnum].col." "
            let line = b:lines[lnum+1]
        elseif b:obj_dict[lnum].type == 'spl_table'
            let cate = " " . b:obj_dict[lnum].row . '+' 
                        \  . b:obj_dict[lnum].col . " "
        elseif b:obj_dict[lnum].type == 'exp'
            let cate = "."
        elseif b:obj_dict[lnum].type == 'block'
            let cate = ":"
        elseif b:obj_dict[lnum].type == 'trans'
            let cate = "-"
            let line = strtrans(line)
        endif
    endif
    let max_len = winwidth(0)-12
    if len(line) <= max_len
        let line = line."  ".repeat('-',max_len) 
    endif
    let line = printf("%-4s| %s", cate, line)
    let line = printf("%-".max_len.".".(max_len)."s", line)
    let num  = printf("%5s+", (v:foldend-lnum))
    return  line."[".num."]"
endfun "}}}
fun! riv#fold#update() "{{{
    if  &filetype!='rst'
        return
    endif
    if g:riv_fold_level > 0
        normal! zx
    else
        call riv#fold#init()
    endif
endfun "}}}
fun! riv#fold#init() "{{{
    call s:init_stat()
endfun "}}}

let &cpo = s:cpo_save
unlet s:cpo_save
