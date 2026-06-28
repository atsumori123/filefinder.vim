let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" バックグラウンド処理の実行
"---------------------------------------------------------------
function! s:RunBackgroundJob(cmd) abort
	let exit = []
	let lines = []
	let jopts = {
		\ 'out_cb': { j, str -> add(lines, str) },
		\ 'err_cb': { j, str -> add(lines, str) },
		\ 'exit_cb': { j, code -> add(exit, code) }}
	let job = job_start(a:cmd, jopts)
	call ch_close_in(job)
	while ch_status(job) !~# '^closed$\|^fail$' || job_status(job) ==# 'run'
		sleep 1m
	endwhile

	return [lines, exit[0]]
endfunction

"---------------------------------------------------------------
" バックグラウンド処理が可能か
"---------------------------------------------------------------
function! filefinder#git#is_bgjob() abort
	return exists('*ch_close_in') ? 1 : 0
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリの取得
"---------------------------------------------------------------
function! filefinder#git#git_cmd(command)
	if filefinder#git#is_bgjob()
		let result = s:RunBackgroundJob(a:command)
		return result[1] == 0 ? result[0]: []
	else
		let result = systemlist(join(a:command, ' '))
		return v:shell_error == 0 ? result : []
	endif
endfunction

"---------------------------------------------------------------
" リポジトリ最上位ディレクトリの取得
"---------------------------------------------------------------
function! filefinder#git#get_git_root() abort
	return filefinder#git#git_cmd(['git', '-C', expand('%:h:p'), 'rev-parse', '--show-toplevel'])
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
