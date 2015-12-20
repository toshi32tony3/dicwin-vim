" vi:set ts=8 sts=2 sw=2 tw=0 nowrap:
"
" dicwin.vim - Dictionary window
"
" Maintainer:   MURAOKA Taro <koron.kaoriya@gmail.com>
" Last Change:  13-Dec-2015.
" Commands:     <Leader>k  Search word under cursor.
"               <Leader>/  Search prompted word.
"               <Leader>c  Close dictionary window.
"               <Leader>n  Search next. (with last word)
"               <Leader>p  Search previous. (with last word)
"               <Leader>w  Jump to dictionary window (if exists)
" Require:      &runtimepath/dict/gene.txt or &runtimepath/gene.txt
"
" URL where you can get 'gene.txt':
"   http://www.namazu.org/~tsuchiya/sdic/data/gene.html

scriptencoding utf-8

if exists('plugin_dicwin_disable')
  finish
endif
let s:myname = expand('<sfile>:t:r')

let s:lastword = ''
let s:lastpattern = ''

function! s:DicwinOnload()
  call s:DetermineDictpath()
  if filereadable(g:dicwin_dictpath)
    call s:SetupKeymap()
  endif
endfunction

function! s:DetermineDictpath()
  " Search default dictionary
  if !exists('g:dicwin_dictpath')
    let s:dict = 'gene.txt'
    let g:dicwin_dictpath = s:GlobPath(&rtp, 'dict/'.s:dict)
    if g:dicwin_dictpath == ''
      let g:dicwin_dictpath = s:GlobPath(&rtp, s:dict)
    endif
    unlet s:dict
  endif
  " Windows return '\\' as directory separator in globpath(), replace it.
  if has('win32') || has('win64')
    let g:dicwin_dictpath = substitute(g:dicwin_dictpath, '\\', '/', 'g')
  endif
endfunction

function! s:GlobPath(paths, target)
  let list = split(globpath(a:paths, a:target), "\n")
  if len(list) <= 0
    return ''
  else
    return list[0]
  end
endfunction

" Keymaps
function! s:SetupKeymap()
  nnoremap <silent> <Plug>(dicwin-cword)        :call <SID>OpenDictionary(g:dicwin_dictpath, expand('<cword>'))<CR>
  inoremap <silent> <Plug>(dicwin-cword-i) <Esc>:call <SID>OpenDictionary(g:dicwin_dictpath, expand('<cword>'))<CR>a
  nnoremap <silent> <Plug>(dicwin-next)         :call <SID>Search(g:dicwin_dictpath,         0)<CR>
  nnoremap <silent> <Plug>(dicwin-prev)         :call <SID>Search(g:dicwin_dictpath,         1)<CR>
  nnoremap <silent> <Plug>(dicwin-gowin)        :call <SID>GoDictWindow()<CR>
  nnoremap <silent> <Plug>(dicwin-close)        :call <SID>Close()<CR>
  inoremap <silent> <Plug>(dicwin-close-i) <Esc>:call <SID>Close()<CR>a
  nnoremap <silent> <Plug>(dicwin-query)        :call <SID>Query()<CR>

  if exists('g:dicwin_no_default_mappings')
    return
  else
    let g:dicwin_no_default_mappings = 0
  endif
  nmap <silent> <Leader>k <Plug>(dicwin-cword)
  nmap <silent> <Leader>/ <Plug>(dicwin-query)
  nmap <silent> <Leader>c <Plug>(dicwin-close)
  nmap <silent> <Leader>n <Plug>(dicwin-next)
  nmap <silent> <Leader>p <Plug>(dicwin-prev)
  nmap <silent> <Leader>w <Plug>(dicwin-gowin)

endfunction

"
" WinEnter/WinLeave hooks
"
function! s:DicWinEnter()
  if winbufnr(2) > 0
    exe "normal! 8\<C-W>_"
  else
    exe "quit!"
  endif
  setlocal wrap
endfunction

function! s:DicWinLeave()
  setlocal nowrap
  normal! zt
  2 wincmd _
endfunction

function! s:DicWinUnload()
  if exists('w:dicwin_dicwin')
    unlet w:dicwin_dicwin
  endif
endfunction

"
" GenerateSearchPatternEnglish(word)
"
function! s:GenerateSearchPatternEnglish(word)
  let pat = a:word
  if pat =~ 's$'
    if pat =~ 'ies$'
      let pat = substitute(pat, 'ies$', '\\(ies\\=\\|y\\)', '')
    else
      let pat = pat . '\='
    endif
  elseif pat =~ 'ied$'
    let pat = substitute(pat, 'ied$', '\\(y\\|ied\\|ie\\)\\=', '')
  elseif pat =~ 'ed$'
    let pat = substitute(pat, 'ed$', '\\(ed\\|e\\)\\=', '')
  elseif pat =~ 'ing$'
    if pat =~ '\(.\)\1ing$'
      let pat = substitute(pat, '\(.\)ing$', '\1\\=\\(ing\\|e\\)\\=', '')
    else
      let pat = substitute(pat, 'ing$', '\\(ing\\|e\\)\\=', '')
    endif
  elseif pat =~ 'able$'
    let pat = substitute(pat, 'able$', '\\(able\\|e\\)', '')
  elseif pat =~ '[.,]$'
    let pat = substitute(pat, '[,.]$', '', '')
  endif
  return "\\c" . pat
endfunction

function! s:Query()
  let wquery = input(s:myname. ': Input search word: ')
  return s:OpenDictionary(g:dicwin_dictpath, wquery)
endfunction

"
" Close()
"   Close window of dictionary [a:dic].
"
function! s:Close()
  call s:PrevWindowMark()
  if s:GoDictWindow() >= 0
    close
    call s:PrevWindowRevert()
  endi
endfunction

" Search(dic, dir)
"   dir: 0:next / 1:previous
" Search next/previous word in dictionary.
function! s:Search(dic, dir)
  if filereadable(a:dic) != 1
    return
  endif
  " Check existance of previous searched word
  if s:lastpattern == '' || s:lastword == ''
    echohl Error
    echo s:myname. ': No given word before.'
    echohl None
    return
  endif
  " Initialize variables for direction
  if a:dir == 0
    let cmd = '/'
    let dirname = 'next'
    let restart  = 'TOP'
  else
    let cmd = '?'
    let dirname = 'previous'
    let restart  = 'BOTTOM'
  endif
  " Do search
  call s:PrevWindowMark()
  call s:OpenDictionaryWindow(a:dic)
  let line_before = line('.')
  execute 'silent! normal! ' .cmd. '^' .s:lastpattern. "\\>\<CR>"
  let line_after = line('.')
  " Output result
  if line_before == line_after
    echohl WarningMsg
    echo s:myname. ': No other "' .s:lastword. '".'
  elseif (a:dir == 0 && line_before < line_after) || (a:dir != 0 && line_before > line_after)
    echo s:myname. ': Found ' .dirname. ' "' .s:lastword. '" in line ' .line_after. '.'
  else
    echohl WarningMsg
    echo s:myname. ': Search from ' .restart. ' and found ' .dirname. ' "' .s:lastword. '".'
  endif
  echohl None
  " Revert previous window
  call s:PrevWindowRevert()
endfunction

" OpenDictionary(dic, word)
"   Open window of dictionary [a:dic] and search a:word.
"
function! s:OpenDictionary(dic, word)
  if filereadable(a:dic) != 1
    return
  endif
  if a:word != ''
    if a:word ==# s:lastword
      call s:Search(a:dic, 0)
      return
    endif
    " Remember previous window and open dictionary window
    call s:PrevWindowMark()
    call s:OpenDictionaryWindow(a:dic)
    " Search the word
    let s:lastword = a:word
    let s:lastpattern = s:GenerateSearchPatternEnglish(a:word)
    execute "silent! normal! gg/^" . s:lastpattern . "\\%( [+~]\\|$\\)\<CR>"
    " Output  result
    if line('.') != 1
      echo s:myname . ": Found \"" . s:lastword . '".'
    else
      echohl ErrorMsg
      echo s:myname . ": Can't find \"" . s:lastword . '".'
    endif
    echohl None
  else
    " output 'no word message'
    echohl WarningMsg
    echo s:myname . ": No word at under cursor."
    echohl None
  endif
  " Leave dictionary window
  call s:PrevWindowRevert()
endfunction

function! s:OpenDictionaryWindow(name)
  if filereadable(a:name) != 1
    return
  endif
  if s:GoDictWindow() < 0
    execute "augroup Dictionary"
    execute "autocmd!"
    execute "autocmd WinEnter " . a:name . " call <SID>DicWinEnter()"
    execute "autocmd WinLeave " . a:name . " call <SID>DicWinLeave()"
    execute "autocmd BufUnload " . a:name . " call <SID>DicWinUnload()"
    execute "augroup END"
    execute 'silent normal! :sview ' . a:name ."\<CR>"
    let w:dicwin_dicwin = 1
    let s:lastword = ''
    let s:lastpattern = ''
    setlocal nowrap
  endif
endfunction

function! s:GoDictWindow()
  return s:GoMarkedWindow('dicwin_dicwin')
endfunction

function! s:GetMarkedWindow(name)
  let winnum = 1
  while winbufnr(winnum) >= 0
    if getwinvar(winnum, a:name) > 0
      return winnum
    endif
    let winnum = winnum + 1
  endwhile
  return -1
endfunction

function! s:GoMarkedWindow(name)
  let winnum = s:GetMarkedWindow(a:name)
  if winnum > 0 && winnr() != winnum
    execute winnum.'wincmd w'
  endif
  return winnum
endfunction

function! s:PrevWindowMark()
  let w:dicwin_prevwin = 1
endfunction

function! s:PrevWindowRevert()
  if s:GoMarkedWindow('dicwin_prevwin') > 0
    unlet w:dicwin_prevwin
  endif
endfunction

call s:DicwinOnload()
