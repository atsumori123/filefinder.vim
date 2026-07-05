let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" バックグラウンド処理の実行
"---------------------------------------------------------------
function! s:run_background_job(cmd) abort
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
function! s:is_bgjob() abort
	return exists('*ch_close_in') ? 1 : 0
endfunction

"---------------------------------------------------------------
" ジョブコマンドの実行
"---------------------------------------------------------------
function! filefinder#job#run_job(command)
	if s:is_bgjob()
		let result = s:run_background_job(a:command)
		echo result[0]
		return result[1] == 0 ? result[0]: []
	else
		let result = systemlist(join(a:command, ' '))
		return v:shell_error == 0 ? result : []
	endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
