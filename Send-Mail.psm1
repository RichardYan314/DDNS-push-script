#$cred = (Get-Credential)

$user = "[data deleted]"
$pw = "[data deleted]"
$pw = ConvertTo-SecureString -String $pw -AsPlainText -Force
$outlookSmtp = @{
    SmtpServer = "smtp.office365.com"
    Port = 587
    Credential = New-Object System.Management.Automation.PSCredential $user, $pw
    UseSsl=$true
}

$user = "[data deleted]"
$pw = "[data deleted]"
$pw = ConvertTo-SecureString -String $pw -AsPlainText -Force
$qqSmtp = @{
    SmtpServer = "smtp.qq.com"
    Port = 587
    Credential = New-Object System.Management.Automation.PSCredential $user, $pw
    UseSsl=$true
}

Function Send-Mail {
    [CmdletBinding()]
    Param(
    #[Parameter(Mandatory=$True)]
    #[string]
    #$NewIp
    )

    $mail = @{
        From = "[data deleted]"
        To = "[data deleted]"
        Subject = "Test Title1"
        Body = "Test Body"
    }

    $sendParam = $outlookSmtp + $mail
    Out-String -InputObject $outlookSmtp
    Out-String -InputObject $mail
    Out-String -InputObject $sendParam
    #send the message
    Send-MailMessage @sendParam -Verbose
}

Function Send-Mail2 {
    [CmdletBinding()]
    Param(
    #[Parameter(Mandatory=$True)]
    #[string]
    #$NewIp
    )

    $smtp = New-Object Net.Mail.SmtpClient $smtpServer, 465
    $smtp.Credentials = $cred
    $smtp.Send("[data deleted]", "[data deleted]", "Test Title", "Test Body")
}