# shipyard

## Installing

### Powershell (recommended)

Open a powershell terminal and execute the following command.
The installer downloads the `pwr` cmdlet and puts its location on the user path.

	iex (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/airpwr/shipyard/main/cmd/install.ps1').Content

### Manually
Save the `cmd\pwr.ps1` cmdlet to a file on your machine and add that location to the `path` environment variable.
