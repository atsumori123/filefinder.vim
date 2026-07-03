if exists('loaded_filefinder')
	finish
endif
let loaded_filefinder = 1

command! -nargs=? -complete=dir FF call filefinder#start_files(<f-args>)
command! -nargs=? OL call filefinder#start_oldfiles()

autocmd BufRead			* call filefinder#add_oldfile(expand('<abuf>'))
"autocmd BufNewFile		* call filefinder#add_oldfile(expand('<abuf>'))
autocmd BufWritePost	* call filefinder#add_oldfile(expand('<abuf>'))
