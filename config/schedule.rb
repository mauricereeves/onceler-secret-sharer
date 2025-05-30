# using the `whenever` gem we can run this job to sweep
# up any secrets that need to expire and make sure they're
# not accessible
every 1.hour do
  runner "CleanupExpiredSecretsJob.perform_later"
end
