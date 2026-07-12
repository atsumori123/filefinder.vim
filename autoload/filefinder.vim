" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

"---------------------------------------------------------------
" 初期化処理
"---------------------------------------------------------------
function! s:init(mode) abort
	let s:pattern		= ""
	let s:old_pattern	= ""
	let s:filefinder	= a:mode

	if a:mode == "F"
		let s:start_dir = ""
	elseif a:mode == "C"
		let s:start_dir = "cache files"
	elseif a:mode == "O"
		let s:start_dir = "oldfiles"
	endif

	if exists('s:timer_id') && s:timer_id
		call timer_stop(s:timer_id)
	endif
	let s:timer_id = 0
endfunction

function! s:is_mode(mode) abort
	return s:filefinder == a:mode ? 1 : 0
endfunction

"---------------------------------------------------------------
" キャッシュディレクトリの取得
"---------------------------------------------------------------
function! s:get_cashe_directory() abort
	if has('unix') || has('macuni')
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

	execute "lcd " a:start_dir
	if executable('git') && !empty(finddir('.git', a:start_dir . ';'))
		" gitコマンドでファイル検索
		let list = filefinder#job#run_job(['git', '-C', a:start_dir, 'ls-files', '--others', '--exclude-standard', '--cached'])
		" ディレクトリを除外してファイルのみにする
		call filter(list, '!isdirectory(a:start_dir . '/' . v:val)')
	else
		" vimのglobpathで検索
		let list = split(globpath(a:start_dir, '**/*', 1), "\n") + split(globpath(a:start_dir, '**/.*', 1), "\n")
		" ディレクトリを除外してファイルのみにする
		call filter(list, '!isdirectory(v:val)')
		" 相対パスにする
		call map(list, 'fnamemodify(v:val, ":.")')
	endif
	execute "lcd -"

	" 除外ディレクトリを正規表現で結合してフィルタリング
	let ignore_pattern = join(ignore_dirs, '/' . '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" 除外ファイルでフィルタリング
	let ignore_pattern = join(ignore_files, '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	redraw | echo ""

	return list
endfunction

"---------------------------------------------------------------
" キャッシュファイルの一覧を取得
"---------------------------------------------------------------
function! s:get_cache_files() abort
	let s:FILES = []
	for v in readdir(s:get_cashe_directory())
	    " 先頭のドライブ名の % を : に戻す
		let s = substitute(v, '^\a\zs%', ':', '')
		" 残りの % を / に戻す
    	let s = substitute(s, '%', '/', 'g')

		call add(s:FILES, s)
	endfor
endfunction

"---------------------------------------------------------------
" より上位のキャッシュファイルが存在するディレクトリを取得する
"---------------------------------------------------------------
function! s:get_higher_level_directory(start_dir) abort
	let cache_dir = s:get_cashe_directory()

	let parts = split(a:start_dir, '/')
	for i in range(0, len(parts) - 1, 1)
		let dir = join(parts[:i], '/')
		let cache_file = substitute(dir, '\([\/]\|^\a\zs:\)', '%', 'g').'.txt'
		if filereadable(cache_dir . '/' . cache_file)
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
function! s:on_select(win, result) abort
	" <ESC>の場合、終了
	if a:result == -1 | return | endif

	" 選択項目を取得
	let file = trim(win_execute(a:win, 'echo getline(".")'))

	if s:is_mode("F")			" filefinderの場合
		" 相対パスを絶対パスに変換
		let filepath = printf("%s/%s", s:start_dir, s:escape_filename(file))
	elseif s:is_mode("O")		" oldfilesの場合
		" 絶対パスの部分を抽出
		let filepath = matchstr(file, '(\zs.*\ze)')
	else						" キャッシュファイル表示の場合
		" 選択キャッシュファイルに切り替え
		let start_dir = substitute(file, '%', '/', 'g')[:-5]
		if isdirectory(start_dir) | call filefinder#start_files(start_dir) | endif
		return
	endif

	if has("nvim") | call nvim_win_close(0, 1) | endif

	let winnum = bufwinnr('^' . filepath . '$')
	if winnum != -1
		exe winnum . 'wincmd w'
	else
		exe "edit " filepath
	endif

	unlet s:FILES
endfunction

"-------------------------------------------------------
" Update popup menu
"-------------------------------------------------------
function! s:update_text(win, new_pattern) abort
	" ハイライトを全クリア
	call clearmatches(a:win)

	" ファイルリストを取得
	let f = (len(s:old_pattern) <= len(a:new_pattern)) && stridx(a:new_pattern, s:old_pattern, 0) == 0 ? 1 : 0
	let files = copy(f ? getbufline(winbufnr(a:win), 1, '$') : s:FILES)

	" フィルタリングの条件式を作成
	if len(a:new_pattern)
		let cond = ""
		for v in split(a:new_pattern, "|")
			let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
		endfor
		call filter(files, cond)
	endif

	" タイトルとメニューを更新
	if has("nvim")
		call nvim_win_set_config(a:win, {'title' : printf(" > %s%s[%s:%d] ", a:new_pattern, len(a:new_pattern) ? " " : "", s:start_dir, len(files))})
		call nvim_buf_set_text(0, 0, 0, -1, -1, files)
		call nvim_win_set_cursor(0, [1, 0])
	else
		call popup_setoptions(a:win, {'title' : printf(" > %s%s[%s:%d] ", a:new_pattern, len(a:new_pattern) ? " " : "", s:start_dir, len(files))})
		call popup_settext(a:win, files)
		call win_execute(a:win, 'call cursor(1, 1)')
	endif

	" oldfiles用ハイライト
	if s:is_mode("O")
		call matchadd('Identifier', '^.\{-}\ze(', 10, -1, {'window': a:win})
	endif

	" フィルタリングパターンをハイライト
	if len(a:new_pattern)
		for v in split(a:new_pattern, "|")
			call matchadd('Title', (v =~# '[A-Z]' ? '' : '\c') . v, 10, -1, {'window': a:win})
		endfor
	endif

	let s:old_pattern = a:new_pattern
endfunction

"---------------------------------------------------------------
" reload
"---------------------------------------------------------------
function! s:reload_files(win) abort
	if s:is_mode("F")
		call s:get_files(s:start_dir, 1)
		call s:update_text(a:win, "")
	endif
endfunction

"---------------------------------------------------------------
" キャッシュファイルの一覧表示
"---------------------------------------------------------------
function! s:listup_cache_files(win) abort
	if s:is_mode("F")
		call s:init("C")
		call s:get_cache_files()
		call s:update_text(a:win, "")
	endif
endfunction

"---------------------------------------------------------------
" キャッシュファイルの削除
"---------------------------------------------------------------
function! s:delete_cache_file(win) abort
	if !s:is_mode("C") | return | endif

	" 選択項目を取得
	let file = trim(win_execute(a:win, 'echo getline(".")'))

	" 区切り文字を%に変換
	let cache_file = substitute(file, '\([\/]\|^\a\zs:\)', '%', 'g')

	" 削除
	if delete(s:get_cashe_directory() . '/' . cache_file, '') < 0
		echo "\rCannot delete file: " . file
	else
		echo "\rDeleted file: ". file
		call win_execute(a:win, 'normal! dd')
	endif
endfunction

"---------------------------------------------------------------
" debounce update
"---------------------------------------------------------------
function! s:debounce_update(win, key)
	if a:key == "BS"
		let s:pattern = s:pattern[:-2]
	elseif a:key == "CLR"
		let s:pattern = ""
	else
		let s:pattern .= a:key
	endif

	" タイマーが動いていたら停止
	if s:timer_id != 0 | call timer_stop(s:timer_id) | endif
	" 100ms 入力が止まったら実行
	let s:timer_id = timer_start(100, {-> s:update_text(a:win, s:pattern)})
endfunction

"---------------------------------------------------------------
" popup filter
"---------------------------------------------------------------
function! s:popup_filter(win, key) abort
	if a:key =~ '^[a-z0-9_._\|\ ]\+$'
		call s:debounce_update(a:win, a:key)
		return 1

	elseif a:key == "\<BS>"
		call s:debounce_update(a:win, "BS")
		return 1

	elseif a:key == "\<c-j>"
		return popup_filter_menu(a:win, 'j')

	elseif a:key == "\<c-k>"
		return popup_filter_menu(a:win, 'k')

	elseif a:key == "\<c-f>"
		call win_execute(a:win, 'normal! 18j')
		return 1

	elseif a:key == "\<c-b>"
		call win_execute(a:win, 'normal! 18k')
		return 1

	elseif a:key == "\<c-u>"
		call s:debounce_update(a:win, "CLR")
		return 1

	elseif a:key == "\<c-l>"
		call s:listup_cache_files(a:win)
		return 1

	elseif a:key == "\<DEL>"
		call s:delete_cache_file(a:win)
		return 1

	elseif a:key == "\<F5>"
		call s:reload_files(a:win)
		return 1
	endif

	return popup_filter_menu(a:win, a:key)
endfunction

if has('nvim')
"-------------------------------------------------------
" ポップアップメニュー起動
"-------------------------------------------------------
function! s:open_popup() abort
	" バッファを作成 (listed=false, scratch(使い捨て)=true)
	let buf = nvim_create_buf(v:false, v:true)

	" create floating window
	let win = nvim_open_win(buf, v:true, {
						\ "title"	: printf(" > [%s:%d]", s:start_dir, len(s:FILES)),
						\ "style"	: "minimal",
						\ "relative": "editor",
						\ "height"	: 20,
						\ "width"	: float2nr(&columns * 3 / 4),
						\ "col"		: float2nr((&columns - 80) * 0.5 - 1),
						\ "row"		: float2nr((&lines - 20) * 0.5 -1),
						\ "border"	: "rounded",
						\ })

	" 変更禁止解除→描画
	setlocal modifiable
	call nvim_buf_set_lines(0, 0, -1, v:false, s:FILES)

	" カーソルを先頭に設定
	call nvim_win_set_cursor(0, [1, 0])

	" set buffer option
	setlocal bufhidden=wipe
	setlocal noswapfile
	setlocal nowrap
	setlocal cursorline

	" フォーカスが外れたら自動で閉じる(winid=0(現在のウィンドウ), force=1)
	autocmd WinLeave <buffer> ++once call nvim_win_close(0, 1)

	" 必要な文字を一括登録
	let keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|"
	for i in range(0, len(keys) - 1)
		let k = escape(keys[i], '|')
		execute printf('nnoremap <buffer> <silent> %s :call <SID>debounce_update(%d, "%s")<CR>', k, win, k)
	endfor

	nnoremap <buffer> <silent> <c-j> j
	nnoremap <buffer> <silent> <c-k> k
	execute printf("nnoremap <buffer> <silent> <nowait> <ESC> :call nvim_win_close(0, v:true)<CR>")
	execute printf('nnoremap <buffer> <silent> <CR>  :call <SID>on_select(%d, 1)<CR>', win)
	execute printf('nnoremap <buffer> <silent> <BS>  :call <SID>debounce_update(%d, "BS")<CR>', win)
	execute printf('nnoremap <buffer> <silent> <F5>  :call <SID>reload_files(%d)<CR>', win)
	execute printf('nnoremap <buffer> <silent> <c-u> :call <SID>debounce_update(%d, "CLR")<CR>', win)
	execute printf('nnoremap <buffer> <silent> <c-l> :call <SID>listup_cache_files(%d)<CR>', win)
	execute printf('nnoremap <buffer> <silent> <DEL> :call <SID>delete_cache_file(%d)<CR>', win)

	return win
endfunction

else
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
endif

"---------------------------------------------------------------
" filefinder#start
"---------------------------------------------------------------
function! filefinder#start_files(...) abort
	call s:init("F")

	" 開始ディレクトリを決定する
	if len(a:000) && !empty(a:000[0])
		let start_dir = resolve(a:000[0])
	else
		" 引数がない場合のデフォルト処理
		let start_dir = s:get_higher_level_directory(resolve(s:get_git_root(expand('%:p:h'))))
	endif

	if empty(start_dir) || !isdirectory(start_dir)
		" キャッシュファイルが存在しない場合は選択画面を表示する
		echohl Error | echomsg "Could not set the starting directory. Select a cache file." | echohl None
		call s:init("C")
		call s:get_cache_files()
		let win = s:open_popup()
		return
	endif

	" 末尾の区切り文字を削除
	let s:start_dir = substitute(start_dir, '[\/]$', '', '')

	" ファイル一覧取得
	call s:get_files(s:start_dir, 0)

	" ポップアップウィンドウで表示
	let win = s:open_popup()
endfunction

"---------------------------------------------------------------
" filefinder#start
"---------------------------------------------------------------
function! filefinder#start_oldfiles() abort
	call s:init("O")

	" ファイル履歴が未ロードでの場合は、vimのoldfilesから取得する
	if !exists('s:OldFiles') | call s:load_oldfiles() | endif

	" 表示形式に変換
	let s:FILES = map(copy(s:OldFiles), 'fnamemodify(v:val, ":t")."  (" . v:val . ")"')

	" ポップアップウィンドウで表示
	let win = s:open_popup()

	" 各行先頭のファイル名の部分をハイライト
	call matchadd('Identifier', '^.\{-}\ze(', 10, -1, {'window': win})
endfunction

"---------------------------------------------------------------
" add to s:OldFiles
"---------------------------------------------------------------
function! filefinder#add_oldfile(bufnr) abort
	if !exists('s:OldFiles') | call s:load_oldfiles() | endif

	" Get the full path to the filename
	let file = fnamemodify(bufname(a:bufnr + 0), ':p')

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
