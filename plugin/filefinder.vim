if exists('loaded_filefinder')
	finish
endif
let loaded_filefinder = 1

command! -nargs=? -complete=dir FF call filefinder#files_start(1, <f-args>)
command! -nargs=? OL call filefinder#oldfiles_start()

autocmd BufRead			* call filefinder#add_oldfile(expand('<abuf>'))
"autocmd BufNewFile		* call filefinder#add_oldfile(expand('<abuf>'))
autocmd BufWritePost	* call filefinder#add_oldfile(expand('<abuf>'))
