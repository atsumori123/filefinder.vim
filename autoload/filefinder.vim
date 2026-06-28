" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

let s:pattern = ""
let s:start_dir = ""

"---------------------------------------------------------------
" キャッシュディレクトリの取得
"---------------------------------------------------------------
function! s:get_cashe_directory() abort
	if has('unix') || has('macunix')
		return $HOME . '/vim_filefinder/'
	elseif has('win32') && $USERPROFILE != ''
		return $USERPROFILE . '\vim_filefinder\'
	else
		return $VIM . '/vim_filefinder/'
	endif
endfunction

"---------------------------------------------------------------
" escape filename
"---------------------------------------------------------------
function! s:escape_filename(file) abort
	if exists("*fnameescape")
		return fnameescape(a:file)
	else
		let esc_filename_chars = ' *?[{`$%#"|!<>();&' . "'\t\n"
		return escape(a:file, esc_filename_chars)
	endif
endfunction

"---------------------------------------------------------------
" 指定ディレクトリ以下のファイル一覧を取得
"---------------------------------------------------------------
function! s:get_file_list_from_directory(start_dir) abort
	let ignore_dirs = [
		\ '\.hg',
		\ '\.svn',
		\ '\.cdv',
		\ 'blib',
		\ 'CVS',
		\ 'SCCS',
		\ '_build',
		\ ]

	let ignore_files = [
		\ '#.+#$',
		\ '[._].*\.swp$',
		\ 'core\.\d+$',
		\ '\.exe$',
		\ '\.so$',
		\ '\.bak$',
		\ '\.png$',
		\ '\.jpg$',
		\ '\.gif$',
		\ '\.zip$',
		\ '\.rar$',
		\ '\.tar\.gz$',
		\ ]

	echohl Search | echomsg ">>> file searching >>>" | echohl None

	" 環境に合わせたセパレータを決定
	let separator = stridx(a:start_dir, '/') > -1 ? '/' : '\\'

	" globpathでディレクトリ以下を再帰的に検索してファイルを抽出
	let list = globpath(a:start_dir, '**/*', 0, 1)

	" 除外ディレクトリを正規表現で結合
	let ignore_pattern = join(ignore_dirs, separator . '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" ディレクトリを除外してファイルのみにする
	call filter(list, '!isdirectory(v:val)')

	" 除外ファイルでフィルタリング
	let ignore_pattern = join(ignore_files, '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" 相対パスにする
	let dir = escape(a:start_dir, '\') . separator
	call map(list, 'substitute(v:val, dir, "", "")')

	redraw | echo ""

	return list
endfunction

"---------------------------------------------------------------
" ファイル一覧の取得
"---------------------------------------------------------------
function! s:get_files(start_dir, force) abort
	" キャッシュファイル名
	let cache_dir = s:get_cashe_directory()
	let cache_file = cache_dir . substitute(a:start_dir, '\([\/]\|^\a\zs:\)', '%', 'g').'.txt'

	if !filereadable(cache_file) || a:force
		" Get the list of files
		let s:FILES = s:get_file_list_from_directory(a:start_dir)

		" キャッシュファイルを作成。キャッシュディレクトリが無い場合は作成する
		if exists('*mkdir') && !isdirectory(cache_dir)
			silent! call mkdir(cache_dir, 'p')
		endif
		silent! call writefile(s:FILES, cache_file)
	else
		let s:FILES = readfile(cache_file)
	endif
endfunction

"---------------------------------------------------------------
" Selected handler
"---------------------------------------------------------------
function! s:on_select(winid, result) abort
	unlet s:FILES

	" <ESC>の場合、終了
	if a:result == -1 | return | endif

	" 選択項目を取得
	let file = trim(win_execute(a:winid, 'echo getline(".")'))

	" フルパスに変換
	let filepath = printf("%s%s%s", s:start_dir, has('unix') ? '/' : '\\', s:escape_filename(file))

	let winnum = bufwinnr('^' . filepath . '$')
	if winnum != -1
		exe winnum . 'wincmd w'
	else
		exe "edit " filepath
	endif
endfunction

"-------------------------------------------------------
" Update popup menu
"-------------------------------------------------------
function! s:update_text(winid, old_pattern, pattern) abort
	let [old_len, new_len] = [len(a:old_pattern), len(a:pattern)]

	" 変化なしの場合はスキップ
	if old_len == new_len | return | endif

	" フィルタリング
	let files = filter(copy(old_len < new_len ? getbufline(winbufnr(a:winid), 1, '$') : s:FILES), { _, val -> val =~# a:pattern })

	" ハイライト全クリア
	call clearmatches(a:winid)

	" タイトル更新
	call popup_setoptions(a:winid, {'title' : printf(" [%d] > %s ", len(files), a:pattern)})

	" ハイライト再設定
	call matchadd('Title', s:pattern, 10, -1, {'window': a:winid})

	" ポップアップメニューの内容を更新
	call popup_settext(a:winid, files)
endfunction

"---------------------------------------------------------------
" popup filter
"---------------------------------------------------------------
function! s:popup_filter(winid, key) abort
	let old_pattern = s:pattern

	if a:key ==# "\<BS>" || a:key =~ '^[a-z0-9_._]\+$'
		let s:pattern = a:key ==# "\<BS>" ? s:pattern[:-2] : s:pattern . a:key
		call s:update_text(a:winid, old_pattern, s:pattern)
		return 1

	elseif a:key ==# "\<c-j>"
		call win_execute(a:winid, 'normal! j')
		return 1

	elseif a:key ==# "\<c-k>"
		call win_execute(a:winid, 'normal! k')
		return 1

	elseif a:key ==# "\<F5>"
		let s:pattern = ""
		call s:get_files(s:start_dir, 1)
		call s:update_text(a:winid, "dummy", s:pattern)
		return 1

	elseif a:key ==# "\<ESC>"
		call popup_close(a:winid, -1)
		return -1
	endif

	return popup_filter_menu(a:winid, a:key)
endfunction

"---------------------------------------------------------------
" Open popup window
"---------------------------------------------------------------
function! s:open_popup() abort
	let opts = {
			\ 'title':			printf(" [%d] > ", len(s:FILES)),
			\ 'border':			[1,1,1,1],
			\ 'borderchars':	has('unix') ? [] : ['─','│','─','│','┌','┐','┘','└'],
			\ 'padding':		[1,2,1,2],
			\ 'minheight':		20,
			\ 'maxheight':		20,
			\ 'minwidth':		&columns-30,
			\ 'maxwidth':		&columns-30,
			\ 'mapping':		v:false,
			\ 'wrap':			v:false,
			\ 'scrollbar':		0,
			\ 'callback':		function('s:on_select'),
			\ 'filter':			function('s:popup_filter')
			\ }

	const winid = popup_menu(s:FILES, opts)
endfunction

"---------------------------------------------------------------
" filefinder#start
"---------------------------------------------------------------
function! filefinder#start(...) abort
	let s:pattern = ""
	let start_dir = resolve(get(a:000, 0, ""))
	if empty(start_dir)
		let git_root = filefinder#git#get_git_root()
		let start_dir = empty(git_root) ? getcwd() : git_root[0]
	endif

	if $MSYSTEM =~# 'MINGW'
		let s:start_dir = start_dir
	else
		let cwd = getcwd()
		execute "lcd " start_dir
		let s:start_dir = getcwd()
		execute "lcd " cwd
	endif

	" ファイル一覧の取得
	call s:get_files(s:start_dir, 0)

	call s:open_popup()
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save

