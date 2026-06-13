use std::process::Command;

#[tauri::command]
fn executar_proton_pack(
    app_id: Option<String>,
    game_dir: Option<String>,
    exe_rel: Option<String>,
    display_name: Option<String>,
    bundle_proton: bool,
) -> Result<String, String> {
    
    let mut bash_cmd = Command::new("./proton-pack.sh");

    if let Some(id) = app_id {
        bash_cmd.arg("--steam").arg(id);
    } else if let (Some(dir), Some(exe), Some(name)) = (game_dir, exe_rel, display_name) {
        bash_cmd.arg("--dir").arg(dir).arg("--exe").arg(exe).arg("--name").arg(name);
    } else {
        return Err("Forneça o App ID (Steam) ou Diretório, Executável e Nome.".to_string());
    }

    if bundle_proton {
        bash_cmd.arg("--bundle-proton");
    }

    let output = bash_cmd.output()
        .map_err(|e| format!("Falha ao executar o script bash: {}", e))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

fn main() {
    tauri::Builder::default()
        // Registramos o comando aqui
        .invoke_handler(tauri::generate_handler![executar_proton_pack])
        .run(tauri::generate_context!())
        .expect("erro ao iniciar a aplicação tauri");
}