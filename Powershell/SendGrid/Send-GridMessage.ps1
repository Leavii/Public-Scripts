function Send-GridMessage {

    <#

        .SYNOPSIS
        Warmup, keep alive, or email to SendGrid

        .PARAMETER To
        Required
        Recipient

        .PARAMETER From
        Required
        Sender

        .PARAMETER Subject
        Optional
        Email subject

        .PARAMETER Body
        Optional
        Email body

        .PARAMETER ApiKey
        Required
        SendGrid ApiKey

        .PARAMETER WarmUp
        Optional switch
        Warmup SendGrid over X Days

        .PARAMETER KeepAlive
        Optional switch
        Keep SendGrid alive

        .PARAMETER Indefinite
        Optional switch for KeepAlive
        Will keep SendGrid alive as long as the module is running

        .PARAMETER Hours
        Optional value for KeepAlive and WarmUp
        Will run either switch for specified time.
        Default is 1 month.

        .PARAMETER Days
        Optional value for KeepAlive and WarmUp
        Will run either switch for specified time.
        Default is 1 month.

        .PARAMETER Email
        Optional switch
        Send an email through SendGrid
        
        .PARAMETER Limit
        Optional value for KeepAlive and WarmUp
        Set your SendGrid max limit per day before applying threshold.
        Default is 100 due to the free plan

        .PARAMETER Threshold
        Optional value for KeepAlive and WarmUp
        Set your SendGrid threshold of emails that will be sent.
        After it is met the module will not send any emails the remainder of the day.
        Default is 75(%) due to the free plan

        .PARAMETER MinimumInterval
        Optional value for KeepAlive and WarmUp
        Set the minimum interval for how long we must wait before sending a new email.
        This is intended to prevent accidental spamming.
        Default is 600 seconds (10 minutes).

        .EXAMPLE
        Send-GridMessage -To "email@address" -From "email@address" -ApiKey "SendGrid-ApiKey" -KeepAlive -Indefinite -Threshold 50
        
        .NOTES
        Name       : Send-GridMessage.ps1
        Author     : Jacob Johns
        Email      : iam@jacobjohns.com
        Version    : 1.0.2
        DateCreated: 4/28/2024
        DateUpdated: 4/28/2024
        
        .LINK
        

    #>

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true)]
        [string] $To,
        [Parameter(Mandatory=$true)]
        [string] $From,
        [Parameter(Mandatory=$false)]
        [string] $Subject,
        [Parameter(Mandatory=$false)]
        [string] $Body,
        [Parameter(Mandatory=$true)]
        [string] $ApiKey,
        [Parameter(Mandatory=$false)]
        [switch] $WarmUp,
        [Parameter(Mandatory=$false)]
        [switch] $KeepAlive,
        [Parameter(Mandatory=$false)]
        [switch] $Indefinite,
        [Parameter(Mandatory=$false)]
        [int] $Hours,
        [Parameter(Mandatory=$false)]
        [int] $Days,
        [Parameter(Mandatory=$false)]
        [switch] $Email,
        [Parameter(Mandatory=$false)]
        [int] $Limit = 100,
        [Parameter(Mandatory=$false)]
        [int] $Threshold = 75,
        [Parameter(Mandatory=$false)]
        [int] $MinimumInterval = 600

    )

    Begin {

        If (!($To -or $From)) {

            $Return = "You must supply a -To and -From parameter"

        } ElseIf ((!$ApiKey)) {

            $Return = "You must supply an -ApiKey"

        } Else {

            $ParametersCheck = @(
                $WarmUp,
                $KeepAlive,
                $Email
            ) | Where-Object{
                $_
            }
            
            If ($($ParametersCheck.Count) -gt 1) {

                $Return = "You can only select one method: Warmup, KeepAlive, or Email"

            } ElseIf ($($ParametersCheck.Count) -eq 0) {

                $Return = "You must select a method: -Warmup, -KeepAlive, or -Email"

            } Else {

                $Today = Get-Date
                $DateCheck = Get-Date
                $Sent = 0

                If ($WarmUp) {

                    $Method = "Warmup"

                } ElseIf ($KeepAlive) {

                    $Method = "KeepAlive"

                } ElseIf ($Email) {

                    $Method = "Email"

                } Else {

                    $Return = "How did you get here?!?!  You must select a method: -Warmup, -KeepAlive, or -Email"

                }
            
                If (!($Email)) {

                    If (!($Days -or $Hours)) {

                        $EndDate = $Today.AddMonths(1)

                    } Else {

                        If ($Days) {

                            $EndDate = $Today.AddDays($Days)

                        }

                        If ($Hours) {

                            $EndDate = $Today.AddHours($Hours)

                        }

                    }

                }

                If ($EndDate) {

                    $Limit = $Limit * ($Threshold / 100)
                    $SecondsInDay = [math]::Round(((((Get-date).AddDays(1)).Date) - (Get-date)).TotalSeconds)
                    $Interval = [math]::Round($SecondsInDay / $Limit)

                }

                If (!($Subject)) {

                    $Subject = "SendGrid $($Method)"

                }

                If ($Body) {

                    $BodyToSend = $Body

                } Else {
                        
                    $BodyToSend = "Your SendGrid $($Method) was sent $($Today). `n`nAs you did not specify a -Body this one was made for you!"

                }                       

                $Headers = @{}
                $Headers.Add("Authorization","Bearer $ApiKey")
                $Headers.Add("Content-Type", "application/json")

            }

        }

    }

    Process {

        If (!($Return)) {

            If ($Indefinite -or $EndDate) {

                Write-Host "Starting...`n"
                
                While ($EndDate -gt $Today) {

                    $IntervalTimer = 0
                    $LimitTimer = 0
                    $Today = Get-Date

                    If (!($Today.Date -eq $DateCheck.Date)) {

                        Write-Host "Happy $($Today.DayOfWeek)!"

                        $DateCheck = Get-Date
                        $Sent = 0
                        $SecondsInDay = [math]::Round(((((Get-Date).AddDays(1)).Date) - (Get-Date)).TotalSeconds)
                        $Interval = $SecondsInDay / $Limit

                    }
                    
                    While ($IntervalTimer -lt $Interval) {
                     
                        $IntervalTimer++
                        $Remainder = $Interval - $IntervalTimer

                        Write-Host "$($Remainder) seconds until next interval`r" -NoNewline
                        Start-Sleep -Seconds 1

                    }                    

                    If ($Indefinite) {

                        $EndDate = $Today.AddDays(1)

                        If (!($Body)) {

                            $BodyToSend = "Your SendGrid $($Method) was sent $($Today) and is set to indefinite. `n`nAs you did not specify a -Body this one was made for you!"
        
                        }

                    } Else {

                        If (!($Body)) {
                        
                            $BodyToSend = "Your SendGrid $($Method) was sent $($Today) and will end on $($EndDate). `n`nAs you did not specify a -Body this one was made for you!"

                        }

                    }

                    $Json = [ordered]@{
                        personalizations = @(
                            @{
                                to = @(
                                    @{
                                        email = $To
                                    }
                                )
                            }
                        )
                        from = @{
                            email = $From
                        }
                        subject = $Subject
                        content = @(
                            @{
                                type = "text/plain"
                                value = $BodyToSend
                            }
                        )
                    } | ConvertTo-Json -Depth 10

                    If ($Interval -gt $MinimumInterval) {

                        If ($Sent -lt $Limit) {

                            Try {
                                
                                Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" -Method Post -Headers $Headers -Body $Json

                            } Catch {

                                $Return = "An error occurred: $_"
                                $EndDate = $Today.AddYears(-1)

                            } Finally {

                                $Return = "Email sent @ $($Today)!"
                                $Sent++

                            }

                        } Else {

                            $Return = "Limit reached for Sent emails $($Sent)/$($Limit)"

                        }

                    } Else {

                        $Return = "MinimumInterval exceeded: $($MinimumInterval) > $($Interval)"

                    }

                    If ($Return -match "MinimumInterval exceeded" -or $Return -match "Limit reached for Sent emails") {

                        $WaitPeriod = [math]::Round(((((Get-Date).AddDays(1)).Date) - (Get-Date)).TotalSeconds + 60)

                        While ($LimitTimer -lt $WaitPeriod) {
                            
                            $LimitTimer++
                            $Remainder = $WaitPeriod - $LimitTimer

                            Write-Host "$($Return): waiting $($Remainder) seconds until tomorrow`r" -NoNewline
                            Start-Sleep -Seconds 1

                        }

                    }

                    Write-Host "$($Return)`n"

                }

                If (!($Error)) {
                    
                    $Return = "EndDate was met!`n"

                }

            } Else {

                $Json = [ordered]@{
                    personalizations = @(
                        @{
                            to = @(
                                @{
                                    email = $To
                                }
                            )
                        }
                    )
                    from = @{
                        email = $From
                    }
                    subject = $Subject
                    content = @(
                        @{
                            type = "text/plain"
                            value = $BodyToSend
                        }
                    )
                } | ConvertTo-Json -Depth 10

                Try {
                        
                    Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" -Method Post -Headers $Headers -Body $Json

                } Catch {

                    $Return = "An error occurred: $_"

                } Finally {

                    $Return = "Email sent!"

                }

            }

        }

    }

    End {
        
        If (!($Return)) {

            $Return = "Failed to return!  I missed a condition!?!?!?"

        }

        Write-Host "$($Return)`n"

    }  

}