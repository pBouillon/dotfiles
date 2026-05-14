# Git Flow Utility Functions for PowerShell
# Usage: gitflow <command> <subcommand> <branch-name>

# --- Helper: Check if working directory is clean ---
function Test-GitWorkingDirClean {
    $status = git status --porcelain
    return [string]::IsNullOrWhiteSpace($status)
}

# --- Helper: Run a git command, log it, and abort on failure ---
function Invoke-GitCommand {
    param([string]$Command)
    Log -Level Verbose -Message "Executing: $Command"
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        Log -Level Error -Message "Command failed (exit $LASTEXITCODE): $Command"
        throw "git-flow aborted"
    }
}

# --- Helper: Confirm with the user, then execute and abort on failure ---
function Invoke-GitCommandConfirmed {
    param(
        [string]$Command,
        [string]$Message
    )
    Log -Level Info -Message $Message

    if ($Command) {
        Log -Level Debug "Pending command: $Command"
    }

    $response = Read-Host "  [Y/n]"
    if ($response -notin @('Y', 'y', '')) {
        Log -Level Warning -Message "Command declined by user."
        return $false
    }

    if ($Command) {
        Log -Level Verbose -Message "Executing: $Command"
        Invoke-Expression $Command
        if ($LASTEXITCODE -ne 0) {
            Log -Level Error -Message "Command failed (exit $LASTEXITCODE): $Command"
            throw "git-flow aborted"
        }
    }

    return $true
}

# --- Helper: Check if a branch exists locally ---
function Test-GitBranch {
    param([string]$Branch)
    git rev-parse --verify $Branch 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

# --- Helper: Read git-flow config with a fallback default ---
function Get-GitFlowConfig {
    param([string]$Key, [string]$Default)
    $val = git config --get "gitflow.$Key" 2>$null
    if ($val) { $val } else { $Default }
}

# --- Init Command ---
function Invoke-GitFlowInit {
    Invoke-GitCommand "git config gitflow.branch.main    main"
    Invoke-GitCommand "git config gitflow.branch.develop develop"
    Invoke-GitCommand "git config gitflow.prefix.feature feature/"
    Invoke-GitCommand "git config gitflow.prefix.release release/"
    Invoke-GitCommand "git config gitflow.prefix.hotfix  hotfix/"

    $develop = Get-GitFlowConfig "branch.develop" "develop"

    if (Test-GitBranch -Branch $develop) {
        Log -Level Warning -Message "Branch '$develop' already exists, skipping creation."
        Invoke-GitCommand "git checkout $develop"
    } else {
        Invoke-GitCommand "git checkout -b $develop"
        $pushed = Invoke-GitCommandConfirmed `
            -Command "git push -u origin $develop" `
            -Message "This will push the new $develop branch to origin."

        if (-not $pushed) { return }
    }

    Log -Level Success -Message "Initialized Git Flow: main and develop branches ready."
}

# --- Feature Commands ---
function Invoke-GitFlowFeature {
    param([string]$SubCommand, [string]$BranchName)

    $develop = Get-GitFlowConfig "branch.develop" "develop"
    $branch  = "$(Get-GitFlowConfig 'prefix.feature' 'feature/')$BranchName"

    switch ($SubCommand) {
        "start" {
            if (Test-GitBranch -Branch $branch) {
                Log -Level Error -Message "Branch $branch already exists!"
                return
            }
            Invoke-GitCommand "git checkout $develop"
            $null = Invoke-GitCommandConfirmed `
                -Command "git pull origin $develop" `
                -Message "This will pull the latest changes from origin/$develop."

            Invoke-GitCommand "git checkout -b $branch"
            Log -Level Success -Message "Started feature branch: $branch"
        }
        "finish" {
            if (-not (Test-GitBranch -Branch $branch)) {
                Log -Level Error -Message "Branch $branch does not exist!"
                return
            }

            Log -Level Warning -Message "Features should usually be merged via Merge Requests."
            Log -Level Warning -Message "Finishing here will merge locally and bypass code review."

            $proceed = Invoke-GitCommandConfirmed `
                -Message "Are you sure you want to bypass the Merge Request process?"

            if (-not $proceed) {
                Log -Level Info -Message "Action cancelled. Please use 'publish' to push for an MR."
                return
            }

            Invoke-GitCommand "git checkout $develop"
            Invoke-GitCommand "git merge --no-ff $branch"
            Invoke-GitCommand "git branch -d $branch"

            $pushed = Invoke-GitCommandConfirmed `
                -Command "git push origin $develop" `
                -Message "This will push $develop to origin."

            if ($pushed) {
                Log -Level Success -Message "Finished feature branch: $branch"
            } else {
                Log -Level Warning -Message "Feature merged locally, but changes were not pushed."
            }
        }
        "publish" {
            if (-not (Test-GitBranch -Branch $branch)) {
                Log -Level Error -Message "Branch $branch does not exist!"
                return
            }
            $pushed = Invoke-GitCommandConfirmed `
                -Command "git push -u origin $branch" `
                -Message "This will push $branch to origin."

            if ($pushed) { Log -Level Success -Message "Published feature branch: $branch" }
        }
        default { Log -Level Error -Message "Invalid subcommand for feature." }
    }
}

# --- Release Commands ---
function Invoke-GitFlowRelease {
    param([string]$SubCommand, [string]$BranchName)

    # Normalize input: Strip leading 'v' if it exists
    $versionNumber = $BranchName -replace '^v', ''

    # Validate SemVer format on the stripped number (X.Y.Z)
    if ($versionNumber -notmatch '^\d+\.\d+\.\d+$') {
        Log -Level Error -Message "Invalid version format. Please use X.Y.Z or vX.Y.Z. Received: $BranchName"
        return
    }

    $main    = Get-GitFlowConfig "branch.main"    "main"
    $develop = Get-GitFlowConfig "branch.develop" "develop"
    $branch  = "$(Get-GitFlowConfig 'prefix.release' 'release/')$versionNumber"
    $tag     = "v$versionNumber"

    switch ($SubCommand) {
        "start" {
            if (-not (Test-GitWorkingDirClean)) {
                Log -Level Error -Message "Working directory is dirty. Commit or stash changes before starting a release."; return
            }
            if (Test-GitBranch -Branch $branch) {
                Log -Level Error -Message "Branch $branch already exists!"; return
            }
            Invoke-GitCommand "git checkout $develop"
            $null = Invoke-GitCommandConfirmed -Command "git pull origin $develop" -Message "Syncing develop..."
            Invoke-GitCommand "git checkout -b $branch"
            Log -Level Success -Message "Started release branch: $branch"
        }
        "finish" {
            if (-not (Test-GitWorkingDirClean)) {
                Log -Level Error -Message "Working directory is dirty. Cannot finish release with uncommitted changes."; return
            }
            if (-not (Test-GitBranch -Branch $branch)) {
                Log -Level Error -Message "Branch $branch does not exist!"; return
            }

            Invoke-GitCommand "git checkout $main"
            Invoke-GitCommand "git merge --no-ff $branch"
            Invoke-GitCommand "git tag -a $tag -m 'Release $versionNumber'"
            Invoke-GitCommand "git checkout $develop"
            Invoke-GitCommand "git merge --no-ff $branch"
            Invoke-GitCommand "git branch -d $branch"

            $pushed = Invoke-GitCommandConfirmed -Command "git push origin $main $develop --tags" -Message "Pushing $tag to production..."
            if ($pushed) { Log -Level Success -Message "Finished release: $tag" }
        }
    }
}

# --- Hotfix Commands ---
function Invoke-GitFlowHotfix {
    param([string]$SubCommand, [string]$BranchName)

    $main    = Get-GitFlowConfig "branch.main"    "main"
    $develop = Get-GitFlowConfig "branch.develop" "develop"
    $branch  = "$(Get-GitFlowConfig 'prefix.hotfix' 'hotfix/')$BranchName"
    $tag     = "v$BranchName"

    switch ($SubCommand) {
        "start" {
            if (Test-GitBranch -Branch $branch) {
                Log -Level Error -Message "Branch $branch already exists!"; return
            }
            Invoke-GitCommand "git checkout $main"
            $null = Invoke-GitCommandConfirmed `
                -Command "git pull origin $main" `
                -Message "This will pull the latest changes from origin/$main."
            Invoke-GitCommand "git checkout -b $branch"
            Log -Level Success -Message "Started hotfix branch: $branch"
        }
        "finish" {
            if (-not (Test-GitBranch -Branch $branch)) {
                Log -Level Error -Message "Branch $branch does not exist!"; return
            }
            Invoke-GitCommand "git checkout $main"
            Invoke-GitCommand "git merge --no-ff $branch"
            Invoke-GitCommand "git tag -a $tag -m 'Hotfix $BranchName'"
            Invoke-GitCommand "git checkout $develop"
            Invoke-GitCommand "git merge --no-ff $branch"
            Invoke-GitCommand "git branch -d $branch"

            $pushed = Invoke-GitCommandConfirmed `
                -Command "git push origin $main $develop --tags" `
                -Message "This will push $main, $develop, and tag $tag to origin."

            if ($pushed) {
                Log -Level Success -Message "Finished hotfix: $branch, tagged as $tag."
            } else {
                Log -Level Warning -Message "Hotfix merged/tagged locally, but not pushed."
            }
        }
        default { Log -Level Error -Message "Invalid subcommand for hotfix." }
    }
}

# --- Help Commands ---
function Invoke-GitFlowHelp {
    Log -Level Info -Message "Usage: git-flow <command> [subcommand] [branch-name]"
    Log -Level Info -Message ""
    Log -Level Info -Message "Initialization:"
    Log -Level Info -Message "  init                           Initialize git-flow on the current repo"
    Log -Level Info -Message ""
    Log -Level Info -Message "Feature Commands:"
    Log -Level Info -Message "  feature  start   <name>        Create feature branch off develop"
    Log -Level Info -Message "  feature  finish  <name>        Merge feature into develop, delete branch"
    Log -Level Info -Message "  feature  publish <name>        Push feature branch to origin"
    Log -Level Info -Message ""
    Log -Level Info -Message "Release Commands:"
    Log -Level Info -Message "  release  start   <version>     Create release branch off develop"
    Log -Level Info -Message "  release  finish  <version>     Merge into main & develop, tag, push"
    Log -Level Info -Message ""
    Log -Level Info -Message "Hotfix Commands:"
    Log -Level Info -Message "  hotfix   start   <version>     Create hotfix branch off main"
    Log -Level Info -Message "  hotfix   finish  <version>     Merge into main & develop, tag, push"
    Log -Level Info -Message ""
    Log -Level Info -Message "Help:"
    Log -Level Info -Message "  help                           Show this message"
}

# --- Master Entry Point ---
function gitflow {
    param(
        [Parameter(Position = 0)]
        [ValidateSet('feature', 'release', 'hotfix', 'init', 'help', '')]
        [string]$Command = '',
        [Parameter(Position = 1)]
        [string]$SubCommand,
        [Parameter(Position = 2)]
        [string]$BranchName
    )

    switch ($Command) {
        '' { Invoke-GitFlowHelp }
        "feature" {
            if (-not $SubCommand -or -not $BranchName) {
                Log -Level Error -Message "Usage: gitflow feature [start|finish|publish] <branch-name>"; return
            }
            Invoke-GitFlowFeature -SubCommand $SubCommand -BranchName $BranchName
        }
        "release" {
            if (-not $SubCommand -or -not $BranchName) {
                Log -Level Error -Message "Usage: gitflow release [start|finish] <branch-name>"; return
            }
            Invoke-GitFlowRelease -SubCommand $SubCommand -BranchName $BranchName
        }
        "hotfix" {
            if (-not $SubCommand -or -not $BranchName) {
                Log -Level Error -Message "Usage: gitflow hotfix [start|finish] <branch-name>"; return
            }
            Invoke-GitFlowHotfix -SubCommand $SubCommand -BranchName $BranchName
        }
        "init" { Invoke-GitFlowInit }
        "help" { Invoke-GitFlowHelp }
    }
}
