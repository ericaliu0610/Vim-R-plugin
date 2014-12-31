" This file contains code used only on Windows

let g:rplugin_sumatra_path = ""
let g:rplugin_python_initialized = 0

" Vim and R must have the same architecture
if has("win64")
    let g:vimrplugin_i386 = 0
else
    let g:vimrplugin_i386 = 1
endif

if g:vimrplugin_Rterm
    let b:rplugin_R = "Rgui.exe"
else
    let b:rplugin_R = "Rterm.exe"
endif
if !exists("g:rplugin_rpathadded")
    if exists("g:vimrplugin_r_path")
        if !isdirectory(g:vimrplugin_r_path)
            call RWarningMsgInp("vimrplugin_r_path must be a directory (check your vimrc)")
            let g:rplugin_failed = 1
            finish
        endif
        if !filereadable(g:vimrplugin_r_path . "\\Rgui.exe")
            call RWarningMsgInp('File "' . g:vimrplugin_r_path . '\Rgui.exe" is unreadable (check vimrplugin_r_path in your vimrc).')
            let g:rplugin_failed = 1
            finish
        endif
        let $PATH = g:vimrplugin_r_path . ";" . $PATH
        let g:rplugin_Rgui = g:vimrplugin_r_path . "\\Rgui.exe"
    else
        let rip = filter(split(system('reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s'), "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
        let g:rdebug_reg_rpath_1 = rip
        if len(rip) > 0
            let s:rinstallpath = substitute(rip[0], '.*InstallPath.*REG_SZ\s*', '', '')
            let s:rinstallpath = substitute(s:rinstallpath, '\n', '', 'g')
            let s:rinstallpath = substitute(s:rinstallpath, '\s*$', '', 'g')
            let g:rdebug_reg_rpath_2 = s:rinstallpath
        endif

        if !exists("s:rinstallpath")
            call RWarningMsgInp("Could not find R path in Windows Registry. If you have already installed R, please, set the value of 'vimrplugin_r_path'.")
            let g:rplugin_failed = 1
            finish
        endif
        if isdirectory(s:rinstallpath . '\bin\i386')
            if !isdirectory(s:rinstallpath . '\bin\x64')
                let g:vimrplugin_i386 = 1
            endif
            if g:vimrplugin_i386
                let $PATH = s:rinstallpath . '\bin\i386;' . $PATH
                let g:rplugin_Rgui = s:rinstallpath . '\bin\i386\Rgui.exe'
            else
                let $PATH = s:rinstallpath . '\bin\x64;' . $PATH
                let g:rplugin_Rgui = s:rinstallpath . '\bin\x64\Rgui.exe'
            endif
        else
            let $PATH = s:rinstallpath . '\bin;' . $PATH
            let g:rplugin_Rgui = s:rinstallpath . '\bin\Rgui.exe'
        endif
        unlet s:rinstallpath
    endif
    let g:rplugin_rpathadded = 1
endif
let g:vimrplugin_term_cmd = "none"
let g:vimrplugin_term = "none"
if !exists("g:vimrplugin_r_args")
    let g:vimrplugin_r_args = "--sdi"
endif
if g:vimrplugin_Rterm
    let g:rplugin_Rgui = substitute(g:rplugin_Rgui, "Rgui", "Rterm", "")
endif

if !exists("g:vimrplugin_R_window_title")
    if g:vimrplugin_Rterm
        let g:vimrplugin_R_window_title = "Rterm"
    else
        let g:vimrplugin_R_window_title = "R Console"
    endif
endif

function FindSumatra()
    if executable($ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe")
        let g:rplugin_sumatra_path = $ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe"
        return 1
    endif
    let smtr = system('reg.exe QUERY "HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths" /v "SumatraPDF.exe"')
    if len(smtr) > 0
        let g:rdebug_reg_personal = smtr
        let smtr = substitute(smtr, '.*REG_SZ\s*', '', '')
        let smtr = substitute(smtr, '\n', '', 'g')
        let smtr = substitute(smtr, '\s*$', '', 'g')
        if executable(smtr)
            let g:rplugin_sumatra_path = smtr
            return 1
        else
            call RWarningMsg('Sumatra not found: "' . smtr . '"')
        endif
    else
        call RWarningMsg("SumatraPDF not found in Windows registry.")
    endif
    return 0
endfunction

function InitializePython()
    " python3 has priority over python
    if has("python3")
        command! -nargs=+ Py :py3 <args>
        command! -nargs=+ PyFile :py3file <args>
    elseif has("python")
        command! -nargs=+ Py :py <args>
        command! -nargs=+ PyFile :pyfile <args>
    else
        command! -nargs=+ Py :
        command! -nargs=+ PyFile :
    endif
    exe "PyFile " . substitute(g:rplugin_home, " ", '\\ ', "g") . '\r-plugin\windows.py'
    let g:rplugin_python_initialized = 1
endfunction

function StartR_Windows()
    if !g:vimrplugin_libcall_send && !g:rplugin_python_initialized
        call InitializePython()
    endif
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        let repl = libcall(g:rplugin_vimcom_lib, "IsRRunning", 'No argument')
        if repl =~ "^Yes"
            call RWarningMsg('R is already running.')
            return
        else
            let g:SendCmdToR = function('SendCmdToR_fake')
            let g:rplugin_r_pid = 0
        endif
    endif

    if !executable(g:rplugin_Rgui)
        call RWarningMsg('R executable "' . g:rplugin_Rgui . '" not found.')
        if exists("g:rdebug_reg_rpath_1")
            call RWarningMsg('DEBUG message 1: >>' . g:rdebug_reg_rpath_1 . '<<')
        endif
        if exists("g:rdebug_reg_rpath_1")
            call RWarningMsg('DEBUG message 2: >>' . g:rdebug_reg_rpath_2 . '<<')
        endif
        return
    endif

    " R and Vim use different values for the $HOME variable.
    let saved_home = $HOME
    let prs = system('reg.exe QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal"')
    if len(prs) > 0
        let g:rdebug_reg_personal = prs
        let prs = substitute(prs, '.*REG_SZ\s*', '', '')
        let prs = substitute(prs, '\n', '', 'g')
        let prs = substitute(prs, '\s*$', '', 'g')
        let $HOME = prs
    endif

    let rcmd = g:rplugin_Rgui
    if g:vimrplugin_Rterm
        let rcmd = substitute(rcmd, "Rgui", "Rterm", "")
    endif
    let rcmd = '"' . rcmd . '" ' . g:vimrplugin_r_args

    silent exe "!start " . rcmd

    let $HOME = saved_home

    if g:vimrplugin_vim_wd == 0
        lcd -
    endif
    let g:SendCmdToR = function('SendCmdToR_Windows')
    call WaitVimComStart()
endfunction

function SendCmdToR_Windows(cmd)
    if g:vimrplugin_ca_ck
        let cmd = "\001" . "\013" . a:cmd . "\n"
    else
        let cmd = a:cmd . "\n"
    endif
    if g:vimrplugin_libcall_send
        let repl = libcall(g:rplugin_vimcom_lib, "SendToRConsole", cmd)
        if repl != "OK"
            call RWarningMsg(repl)
            call ClearRInfo()
        endif
    else
        let slen = len(cmd)
        let str = ""
        for i in range(0, slen)
            let str = str . printf("\\x%02X", char2nr(cmd[i]))
        endfor
        exe "Py" . " SendToRConsole(b'" . str . "')"
    endif
    return 1
endfunction
