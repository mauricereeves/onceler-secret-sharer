Rails.application.configure do
  # Force SSL in production
  # config.force_ssl = true if Rails.env.production?

  # set some security headers
  # config.ssl_options = { hsts: { subdomains: true } }
end
