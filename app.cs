#!/usr/bin/env dotnet run
#:package Azure.Identity@1.13.2
#:package Azure.Security.KeyVault.Secrets@4.7.0

using Azure;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

const string SecretName = "shoosh";
var bicepVaultUrl = Environment.GetEnvironmentVariable("BICEP_KEY_VAULT_URL")
	?? "https://kv-accpol-g79v-aue.vault.azure.net/";
var terraformVaultUrl = Environment.GetEnvironmentVariable("TERRAFORM_KEY_VAULT_URL") 
    ?? "https://kv-kvdemo-dev-lh0m.vault.azure.net/";

var credential = new AzureCliCredential();
var bicepClient = new SecretClient(new Uri(bicepVaultUrl), credential);
var terraformClient = new SecretClient(new Uri(terraformVaultUrl), credential);

Console.WriteLine($"Reading secret '{SecretName}' from both vaults every 1 second. Press Ctrl+C to stop.");
Console.WriteLine($"Bicep Vault: {bicepVaultUrl}");
Console.WriteLine($"Terraform Vault: {terraformVaultUrl}");

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, eventArgs) =>
{
	eventArgs.Cancel = true;
	cts.Cancel();
};

while (!cts.Token.IsCancellationRequested)
{
	var timestamp = DateTimeOffset.Now.ToString("u");
	var bicepValue = await ReadSecretValueAsync(bicepClient, SecretName, cts.Token);
	var terraformValue = await ReadSecretValueAsync(terraformClient, SecretName, cts.Token);

	Console.WriteLine($"[{timestamp}] bicep='{bicepValue}' terraform='{terraformValue}'");

	try
	{
		await Task.Delay(TimeSpan.FromSeconds(1), cts.Token);
	}
	catch (OperationCanceledException)
	{
		break;
	}
}

static async Task<string> ReadSecretValueAsync(SecretClient client, string secretName, CancellationToken cancellationToken)
{
	try
	{
		KeyVaultSecret secret = (await client.GetSecretAsync(secretName, cancellationToken: cancellationToken)).Value;
		return secret.Value;
	}
	catch (RequestFailedException ex)
	{
		return $"<error: {ex.Status} {ex.ErrorCode}>";
	}
	catch (Exception ex)
	{
		return $"<error: {ex.GetType().Name}>";
	}
}
