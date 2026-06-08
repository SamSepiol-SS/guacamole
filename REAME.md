# Guacamole with Custom Branding

## Re-branding
For custom Rebranding You need to make an *extension* for *guacamole* and mount it to the container.


### 1. Edit the main manifest
Edit **guac-manifest.json** and change the `name` and `namespace` values

### 2. Add your logo files
Look inside the [branding](/branding/) directory, replace you files with existing files

> [!TIP]
> **my-logo-b.png** must be your logo in large size
> **my-logo-s.png** must be your logo in small size

### 3. Add your title
Edit [translation](/branding/translations/en.json) file according to your desire title.

### 4. Fix addressing
You need to fix addressing in [favicon.js](/branding/favicon.js) and [branding.css](/branding/css/branding.css) files 

> [!TIP]
> just replace `Sam` with your `namespace` value

### 5. Create your jar file
After you done with customizations, just create a compressed jar file of your extension with bellow command:

```bash
cd branding
zip -r ../custom-branding.jar ./*
chmod 644 ../custom-branding.jar
```
> [!IMPORTANT]
> If you changed the jar file's name, don't forget to modify the compose.yml file

### 6. finally
At the end just up the compose file:

```bash
docker compose up -d
```

