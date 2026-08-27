[CmdletBinding()]
param(
    [string]$Profile = "default",
    [switch]$SkipBuild,
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"

$Region = "ap-south-1"
$ProjectName = "calculator-kubernetes-demo-build"
$RoleName = "calculator-kubernetes-demo-codebuild-role"
$PolicyName = "calculator-kubernetes-demo-codebuild-logs"
$RepositoryUrl = "https://github.com/zapdos-legend/calculator-kubernetes-demo"
$LogGroupName = "/aws/codebuild/$ProjectName"
$AwsArgs = @("--profile", $Profile, "--region", $Region, "--no-cli-pager")

function Invoke-Aws {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Arguments)

    & aws @AwsArgs @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($Arguments -join ' ')"
    }
}

function Test-AwsIamRoleExists {
    # A missing role is an expected AWS CLI failure, so inspect it without
    # weakening error handling for the rest of the script.
    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $AwsOutput = & aws @AwsArgs iam get-role --role-name $RoleName --output json 2>&1
        $AwsExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    if ($AwsExitCode -eq 0) {
        return $true
    }
    if (($AwsOutput | Out-String) -match "NoSuchEntity") {
        return $false
    }

    throw "Unable to check whether IAM role '$RoleName' exists: $($AwsOutput | Out-String)"
}

# Stop before making changes when the selected profile has no usable credentials.
$IdentityJson = & aws @AwsArgs sts get-caller-identity --output json
if ($LASTEXITCODE -ne 0) {
    throw "AWS credentials are unavailable for profile '$Profile'. No resources were changed."
}
$Identity = $IdentityJson | ConvertFrom-Json
$AccountId = $Identity.Account
Write-Host "Using AWS account $AccountId, profile '$Profile', region '$Region'."

if ($Cleanup) {
    $ExistingProject = & aws @AwsArgs codebuild batch-get-projects --names $ProjectName --query "projects[0].name" --output text
    if ($LASTEXITCODE -eq 0 -and $ExistingProject -eq $ProjectName) {
        Invoke-Aws codebuild delete-project --name $ProjectName
    }

    $ExistingLogGroup = & aws @AwsArgs logs describe-log-groups --log-group-name-prefix $LogGroupName --query "logGroups[?logGroupName=='$LogGroupName'].logGroupName | [0]" --output text
    if ($LASTEXITCODE -eq 0 -and $ExistingLogGroup -eq $LogGroupName) {
        Invoke-Aws logs delete-log-group --log-group-name $LogGroupName
    }

    if (Test-AwsIamRoleExists) {
        & aws @AwsArgs iam delete-role-policy --role-name $RoleName --policy-name $PolicyName 2> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The inline policy was already absent; continuing."
        }
        Invoke-Aws iam delete-role --role-name $RoleName
    }

    Write-Host "Cleanup complete."
    exit 0
}

$TrustPolicy = @{
    Version = "2012-10-17"
    Statement = @(@{
        Effect = "Allow"
        Principal = @{ Service = "codebuild.amazonaws.com" }
        Action = "sts:AssumeRole"
    })
} | ConvertTo-Json -Depth 10 -Compress

if (-not (Test-AwsIamRoleExists)) {
    Write-Host "Creating service role '$RoleName'..."
    Invoke-Aws iam create-role --role-name $RoleName --assume-role-policy-document $TrustPolicy --description "Minimal service role for the calculator CodeBuild project"
} else {
    Write-Host "Service role '$RoleName' already exists; reusing it."
    $AttachedPolicies = & aws @AwsArgs iam list-attached-role-policies --role-name $RoleName --query "AttachedPolicies[].PolicyArn" --output text
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to audit managed policies on existing role '$RoleName'."
    }
    $OtherInlinePolicies = & aws @AwsArgs iam list-role-policies --role-name $RoleName --query "PolicyNames[?@!='$PolicyName']" --output text
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to audit inline policies on existing role '$RoleName'."
    }
    if ($AttachedPolicies -or $OtherInlinePolicies) {
        throw "Existing role '$RoleName' has permissions outside this setup. For safety, no policies were removed. Review the role or choose a dedicated clean role before rerunning."
    }
    # Keep the named role's trust relationship correct without replacing the role.
    Invoke-Aws iam update-assume-role-policy --role-name $RoleName --policy-document $TrustPolicy
}

$RoleArn = "arn:aws:iam::${AccountId}:role/$RoleName"
$LogsArn = "arn:aws:logs:${Region}:${AccountId}:log-group:$LogGroupName"
$LogsPolicy = @{
    Version = "2012-10-17"
    Statement = @(@{
        Sid = "WriteProjectBuildLogs"
        Effect = "Allow"
        Action = @("logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents")
        Resource = @($LogsArn, "$LogsArn`:*")
    })
} | ConvertTo-Json -Depth 10 -Compress

# put-role-policy creates or replaces this one project-scoped inline policy.
Invoke-Aws iam put-role-policy --role-name $RoleName --policy-name $PolicyName --policy-document $LogsPolicy

$ProjectDefinition = @{
    name = $ProjectName
    description = "Builds the calculator demo Docker image without publishing it"
    source = @{
        type = "GITHUB"
        location = $RepositoryUrl
        gitCloneDepth = 1
        buildspec = "buildspec.yml"
        reportBuildStatus = $false
    }
    sourceVersion = "refs/heads/main"
    artifacts = @{ type = "NO_ARTIFACTS" }
    environment = @{
        type = "LINUX_CONTAINER"
        image = "aws/codebuild/amazonlinux-x86_64-standard:6.0"
        computeType = "BUILD_GENERAL1_SMALL"
        privilegedMode = $true
        imagePullCredentialsType = "CODEBUILD"
        environmentVariables = @()
    }
    serviceRole = $RoleArn
    logsConfig = @{
        cloudWatchLogs = @{
            status = "ENABLED"
            groupName = $LogGroupName
            streamName = "build"
        }
        s3Logs = @{ status = "DISABLED" }
    }
} | ConvertTo-Json -Depth 10 -Compress

$ExistingProject = & aws @AwsArgs codebuild batch-get-projects --names $ProjectName --query "projects[0].name" --output text
if ($LASTEXITCODE -ne 0) {
    throw "Unable to check whether CodeBuild project '$ProjectName' exists."
}

if ($ExistingProject -eq $ProjectName) {
    Write-Host "Updating CodeBuild project '$ProjectName'..."
    Invoke-Aws codebuild update-project --cli-input-json $ProjectDefinition
} else {
    Write-Host "Creating CodeBuild project '$ProjectName'..."
    Invoke-Aws codebuild create-project --cli-input-json $ProjectDefinition
}

if ($SkipBuild) {
    Write-Host "Project is ready. Build was skipped."
    exit 0
}

# Allow a newly-created role and inline policy a brief IAM propagation window.
Start-Sleep -Seconds 10
$BuildId = Invoke-Aws codebuild start-build --project-name $ProjectName --query "build.id" --output text
Write-Host "Build started: $BuildId"
Write-Host "Status: aws --profile $Profile --region $Region codebuild batch-get-builds --ids `"$BuildId`" --query 'builds[0].[buildStatus,currentPhase]' --output table"
Write-Host "Logs:   aws --profile $Profile --region $Region logs tail `"$LogGroupName`" --follow"
