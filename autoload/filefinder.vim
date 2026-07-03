" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

"---------------------------------------------------------------
" 初期化処理
"---------------------------------------------------------------
function! s:init() abort
	let s:pattern = ""
	let s:start_dir = ""
	let s:filefinder = 0

	" 区切り文字をOS判定で決定
	let s:sep = has('win32') || has('win64') && !&shellslash ? "\\" : "/"
endfunction

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
" get git root
"---------------------------------------------------------------
function! s:get_git_root(dir) abort
	let git_root = finddir('.git', a:dir . ';')
	return empty(git_root) ? "" : fnamemodify(expand(git_root, ':p'), ':p:h:h')
endfunction

"---------------------------------------------------------------
" load oldfiles from oldfiles
"---------------------------------------------------------------
function! s:load_oldfiles() abort
	let s:OldFiles = []

	for f in v:oldfiles
		if len(s:OldFiles) >= 50 | break | endif

		" Convert to full path filename. check readable
		let file = expand(f)
		if !filereadable(file) | continue | endif

		" Add to list
		let file = fnameescape(file)
		call add(s:OldFiles, file)
	endfor
endfunction

"---------------------------------------------------------------
" 指定ディレクトリ以下のファイル一覧を取得
"---------------------------------------------------------------
function! s:get_file_list_from_directory(start_dir) abort
	let ignore_dirs = [
		\ '\.hg',
		\ '\.svn',
		\ '\.cdv',
		\ 'obj',
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
		\ '\.bin$',
		\ '\.a$',
		\ '\.o$',
		\ '\.bak$',
		\ '\.png$',
		\ '\.jpg$',
		\ '\.gif$',
		\ '\.zip$',
		\ '\.rar$',
		\ '\.tar\.gz$',
		\ ]

	echohl Search | echomsg ">>> file searching (" . a:start_dir . ")>>>" | echohl None

	" globpathでディレクトリ以下を再帰的に検索してファイルを抽出
	execute "lcd " a:start_dir
	let list = globpath(a:start_dir, '**/*', 0, 1)
	execute "lcd -"

	" 除外ディレクトリを正規表現で結合してフィルタリング
	let ignore_pattern = join(ignore_dirs, s:sep . '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" ディレクトリを除外してファイルのみにする
	call filter(list, '!isdirectory(v:val)')

	" 除外ファイルでフィルタリング
	let ignore_pattern = join(ignore_files, '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" 相対パスにする
	let dir = escape(a:start_dir, '\') . s:sep
	call map(list, 'substitute(v:val, dir, "", "")')

	redraw | echo ""

	return list
endfunction

"---------------------------------------------------------------
" キャッシュファイルの一覧を取得
"---------------------------------------------------------------
function! s:listup_cache_file(winid) abort
	let s:filefinder = 3
	let s:start_dir = "cache files"

	let s:FILES = []
	for v in readdir(s:get_cashe_directory())
	    " 先頭のドライブ名の % を : に戻す
		let s = substitute(v, '^\a\zs%', ':', '')
		" 残りの % を \ に戻す
    	let s = substitute(s, '%', s:sep, 'g')

		call add(s:FILES, s)
	endfor
endfunction

"---------------------------------------------------------------
" キャッシュファイルの削除
"---------------------------------------------------------------
function! s:delete_cache_file(winid) abort
	" 選択項目を取得
	let file = trim(win_execute(a:winid, 'echo getline(".")'))

	" 区切り文字を%に変換
	let cache_file = substitute(file, '\([\/]\|^\a\zs:\)', '%', 'g')

	" 削除
	if delete(s:get_cashe_directory() . s:sep . cache_file, '') < 0
		echo "\rCannot delete file: " . file
	else
		echo "\rDeleted file: ". file
	endif
endfunction

"---------------------------------------------------------------
" より上位のキャッシュファイルが存在するディレクトリを取得する
"---------------------------------------------------------------
function! s:get_higher_level_directory(start_dir) abort
	let cache_dir = s:get_cashe_directory()

	let parts = split(a:start_dir, s:sep)
	for i in range(0, len(parts) - 1, 1)
		let dir = join(parts[:i], s:sep)
		let cache_file = substitute(dir, '\([\/]\|^\a\zs:\)', '%', 'g').'.txt'
		if filereadable(cache_dir . s:sep . cache_file)
			return dir
		endif
	endfor

	return a:start_dir
endfunction

"---------------------------------------------------------------
" ファイル一覧の取得
"---------------------------------------------------------------
function! s:get_files(start_dir, force) abort
	" 読み込みキャッシュファイルのパス
	let cache_dir = s:get_cashe_directory()
	let cache_file = cache_dir . substitute(a:start_dir, '\([\/]\|^\a\zs:\)', '%', 'g').'.txt'

	if !filereadable(cache_file) || a:force
		" 指定ディレクトリ以下を再帰的に検索してファイル一覧を作成する
		let s:FILES = s:get_file_list_from_directory(a:start_dir)

		" キャッシュディレクトリに保存。キャッシュディレクトリが無い場合は作成する
		if exists('*mkdir') && !isdirectory(cache_dir)
			silent! call mkdir(cache_dir, 'p')
		endif
		silent! call writefile(s:FILES, cache_file)
	else
		" キャッシュファイルから読み込む
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

	if s:filefinder == 1		" filefinderの場合
		" 相対パスを絶対パスに変換
		let filepath = printf("%s%s%s", s:start_dir, s:sep, s:escape_filename(file))
	elseif s:filefinder == 2	" oldfilesの場合
		" 絶対パスの部分を抽出
		let filepath = matchstr(file, '(\zs.*\ze)')
	else						" キャッシュファイル表示の場合
		" 選択キャッシュファイルに切り替え
		let start_dir = substitute(file, '%', s:sep, 'g')[:-5]
		if isdirectory(start_dir) | call filefinder#start_files(start_dir) | endif
		return
	endif

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

	" フィルタリングパターンに変化が無い場合は処理なし
	if old_len == new_len | return | endif

	" ハイライトを全クリア
	call clearmatches(a:winid)

	" ファイルリストを取得
	let files = copy(old_len < new_len ? getbufline(winbufnr(a:winid), 1, '$') : s:FILES)

	" フィルタリングの条件式を作成
	if len(a:pattern)
		let cond = ""
		for v in split(a:pattern, "|")
			let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
		endfor
		call filter(files, cond)
	endif

	" タイトルの更新
	call popup_setoptions(a:winid, {'title' : printf(" > %s [%s:%d] ", a:pattern, s:start_dir, len(files))})
	
	" 表示の更新
	call popup_settext(a:winid, files)

	" oldfiles用ハイライト
	if s:filefinder == 2
		call matchadd('Identifier', '^.\{-}\ze(', 10, -1, {'window': a:winid})
	endif

	" フィルタリングパターンをハイライト
	if len(a:pattern)
		for v in split(a:pattern, "|")
			call matchadd('Title', (v =~# '[A-Z]' ? '' : '\c') . v, 10, -1, {'window': a:winid})
		endfor
	endif
endfunction

"---------------------------------------------------------------
" popup filter
"---------------------------------------------------------------
function! s:popup_filter(winid, key) abort
	let old_pattern = s:pattern

	if a:key ==# "\<BS>" || a:key =~ '^[a-z0-9_._\|\ ]\+$'
		let s:pattern = a:key ==# "\<BS>" ? s:pattern[:-2] : s:pattern . a:key
		call s:update_text(a:winid, old_pattern, s:pattern)
		return 1

	elseif a:key ==# "\<c-j>"
		call win_execute(a:winid, 'normal! j')
		return 1

	elseif a:key ==# "\<c-k>"
		call win_execute(a:winid, 'normal! k')
		return 1

	elseif a:key ==# "\<c-f>"
		call win_execute(a:winid, 'normal! 18j')
		return 1

	elseif a:key ==# "\<c-b>"
		call win_execute(a:winid, 'normal! 18k')
		return 1

	elseif a:key ==# "\<c-u>"
		let s:pattern = ""
		call s:update_text(a:winid, "dummy", s:pattern)
		return 1

	elseif a:key ==# "\<c-l>"
		if s:filefinder != 1 | return 1 | endif
		let s:pattern = ""
		call s:listup_cache_file(a:winid)
		call s:update_text(a:winid, "dummy", "")
		return 1

	elseif a:key ==# "\<DEL>"
		if s:filefinder != 3 | return 1 | endif
		let s:pattern = ""
		call s:delete_cache_file(a:winid)
		call s:listup_cache_file(a:winid)
		call s:update_text(a:winid, "dummy", "")
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
			\ 'title':			printf(" > [%s:%d]", s:start_dir, len(s:FILES)),
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

	return popup_menu(s:FILES, opts)
endfunction

"---------------------------------------------------------------
" filefinder#start
"---------------------------------------------------------------
function! filefinder#start_files(...) abort
	call s:init()
	let s:filefinder = 1

	" 開始ディレクトリを決定する
	let start_dir = resolve(get(a:000, 0, s:get_higher_level_directory(s:get_git_root(expand('%:p:h')))))
	if empty(start_dir) || !isdirectory(start_dir)
		echohl Error | echomsg "Could not set the starting directory." | echohl None
		return
	endif

	" 末尾の区切り文字を削除
	let s:start_dir = substitute(start_dir, '[\/]$', '', '')

	" ファイル一覧取得
	call s:get_files(s:start_dir, 0)

	" ポップアップウィンドウで表示
	let winid = s:open_popup()
endfunction

"---------------------------------------------------------------
" filefinder#start
"---------------------------------------------------------------
function! filefinder#start_oldfiles() abort
	call s:init()
	let s:filefinder = 2
	let s:start_dir = "oldfiles"

	" ファイル履歴が未ロードでの場合は、vimのoldfilesから取得する
	if !exists('s:OldFiles') | call s:load_oldfiles() | endif

	" 表示形式に変換
	let s:FILES = map(copy(s:OldFiles), 'fnamemodify(v:val, ":t")."  (" . v:val . ")"')

	" ポップアップウィンドウで表示
	let winid = s:open_popup()

	" 各行先頭のファイル名の部分をハイライト
	call matchadd('Identifier', '^.\{-}\ze(', 10, -1, {'window': winid})
endfunction

"---------------------------------------------------------------
" add to s:OldFiles
"---------------------------------------------------------------
function! filefinder#add_oldfile(bufnr) abort
	if !exists('s:OldFiles') | call s:load_oldfiles() | endif

	" Get the full path to the filename
	let file = fnamemodify(bufname(a:bufnr), ':p')

	" 以下に該当する場合は履歴に追加しない
	" プレビュー、ファイル名が空、特殊バッファ、リードオンリー
	if &previewwindow || empty(file) || !empty(&buftype) || !filereadable(file)
		return
	endif

	" 既に履歴に存在する場合は一旦削除する
	call filter(s:OldFiles, 'v:val !=# file')

	" 履歴の先頭に追加
	call insert(s:OldFiles, file, 0)

	" 履歴の数を上限に丸める
	let s:OldFiles = s:OldFiles[:50-1]
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
