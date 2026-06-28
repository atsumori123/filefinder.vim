if exists('loaded_filefinder')
	finish
endif
let loaded_filefinder = 1

command! -bar -nargs=? -complete=dir FF call filefinder#start(<f-args>)
