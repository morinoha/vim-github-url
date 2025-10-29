if exists("g:loaded_github_url") || &cp
  finish
endif
let g:loaded_github_url = 1

" Find the nearest VCS directory (.jj or .git) in the parent hierarchy
function! s:findNearestVCS()
  let current_dir = expand("%:p:h")
  let max_depth = 20
  let depth = 0

  while depth < max_depth
    " Check for .jj first (same priority as .git)
    if isdirectory(current_dir . "/.jj")
      return "jj"
    endif

    " Check for .git
    if isdirectory(current_dir . "/.git")
      return "git"
    endif

    " Move to parent directory
    let parent_dir = fnamemodify(current_dir, ":h")
    if parent_dir == current_dir
      " Reached root directory
      break
    endif
    let current_dir = parent_dir
    let depth += 1
  endwhile

  " Default to git if nothing found
  return "git"
endfunction

function! s:repoURL()
  let vcs_type = s:findNearestVCS()

  if vcs_type == "jj"
    " JJ is being used - get remote from git config
    let remote = "origin"
  else
    " Regular git workflow
    let branch_lines = systemlist("git branch --show-current")
    if len(branch_lines) > 0 && branch_lines[0] != ""
      let branch = branch_lines[0]
      let remote_lines = systemlist("git config branch." . branch . ".remote")
      if len(remote_lines) > 0
        let remote = remote_lines[0]
      else
        let remote = "origin"
      endif
    else
      " Detached HEAD or other cases - use origin
      let remote = "origin"
    endif
  endif

  let repo = systemlist("git config --get remote." . remote . ".url | sed 's/\\.git$//' | sed 's_^git@\\(.*\\):_https://\\1/_' | sed 's_^git://_https://_'")[0]

  return repo
endfunction

function! s:revision()
  let vcs_type = s:findNearestVCS()

  if vcs_type == "jj"
    " Get the git HEAD commit hash from jj (what's actually in git/GitHub)
    let git_head_lines = systemlist("jj log -r 'git_head()' -T 'commit_id.short()' --no-graph 2>/dev/null")
    if len(git_head_lines) > 0 && git_head_lines[0] != ""
      return git_head_lines[0]
    endif
  endif

  " Fall back to git
  let rev_lines = systemlist("git rev-parse HEAD 2>/dev/null")
  if len(rev_lines) > 0
    return rev_lines[0]
  endif

  return "HEAD"
endfunction

function! s:path()
  let path_lines = systemlist("git ls-files --full-name " . @%)
  if len(path_lines) > 0
    return path_lines[0]
  endif

  " Fallback to relative path from git root
  let git_root = systemlist("git rev-parse --show-toplevel")[0]
  let full_path = expand("%:p")
  return substitute(full_path, "^" . git_root . "/", "", "")
endfunction

function! s:lineAnchor(repo, first, last)
  let line = "#L" . a:first
  if a:first != a:last
    if a:repo=~#"gitlab"
      let line = line . "-" . a:last
    else
      let line = line . "-L" . a:last
    endif
  endif
  return line
endfunction

function! GitHubURLRepo()
  let url = s:repoURL()

  if has('clipboard')
    let @+ = url
  endif

  echomsg url
endfunction

function! GitHubURLBlob() range
  let repo = s:repoURL()
  let revision = s:revision()
  let path = s:path()
  let line = s:lineAnchor(repo, a:firstline, a:lastline)
  let url = repo . "/blob/" . revision . "/" . path . line

  if has('clipboard')
    let @+ = url
  endif

  echomsg url
endfunction

function! GitHubURLBlame() range
  let repo = s:repoURL()
  let revision = s:revision()
  let path = s:path()
  let line = s:lineAnchor(repo, a:firstline, a:lastline)
  let url = repo . "/blame/" . revision . "/" . path . line

  if has('clipboard')
    let @+ = url
  endif

  echomsg url
endfunction

command! GitHubURLRepo call GitHubURLRepo()

command! -range GitHubURL <line1>,<line2>call GitHubURLBlob()
command! -range GitHubURLBlob <line1>,<line2>call GitHubURLBlob()

command! -range GitHubURLBlame <line1>,<line2>call GitHubURLBlame()
