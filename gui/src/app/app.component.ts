import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { invoke } from '@tauri-apps/api/core';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <main class="container">
      <h1>Proton Pack GUI</h1>
      
      <div class="form-group">
        <label>
          <input type="radio" name="mode" [(ngModel)]="mode" value="steam"> 
          Modo Steam
        </label>
        <label>
          <input type="radio" name="mode" [(ngModel)]="mode" value="dir"> 
          Modo Diretório Local
        </label>
      </div>

      <div *ngIf="mode === 'steam'" class="form-section">
        <label>Steam App ID:</label>
        <input type="text" [(ngModel)]="appId" placeholder="Ex: 1086940">
      </div>

      <div *ngIf="mode === 'dir'" class="form-section">
        <label>Diretório do Jogo (--dir):</label>
        <input type="text" [(ngModel)]="gameDir" placeholder="/caminho/para/o/jogo">
        
        <label>Executável (--exe):</label>
        <input type="text" [(ngModel)]="exeRel" placeholder="jogo.exe">
        
        <label>Nome (--name):</label>
        <input type="text" [(ngModel)]="displayName" placeholder="Meu Jogo">
      </div>

      <div class="form-group">
        <label>
          <input type="checkbox" [(ngModel)]="bundleProton"> 
          Embutir GE-Proton (--bundle-proton)
        </label>
      </div>

      <button (click)="criarAppImage()" [disabled]="isLoading">
        {{ isLoading ? 'Gerando AppImage...' : 'Criar AppImage' }}
      </button>

      <div class="terminal" *ngIf="terminalOutput">
        <strong>Log de Saída:</strong>
        <pre>{{ terminalOutput }}</pre>
      </div>
    </main>
  `,
  styles: [`
    .container { padding: 20px; font-family: sans-serif; max-width: 600px; margin: 0 auto; }
    .form-group, .form-section { margin-bottom: 15px; display: flex; flex-direction: column; gap: 8px; }
    label { display: flex; gap: 10px; align-items: center; }
    input[type="text"] { padding: 8px; border: 1px solid #ccc; border-radius: 4px; }
    button { padding: 10px; background: #0056b3; color: white; border: none; border-radius: 4px; cursor: pointer; }
    button:disabled { background: #ccc; }
    .terminal { margin-top: 20px; padding: 15px; background: #1e1e1e; color: #00ff00; border-radius: 5px; overflow-x: auto; }
  `]
})
export class AppComponent {
  mode: 'steam' | 'dir' = 'steam';
  
  appId = '';
  gameDir = '';
  exeRel = '';
  displayName = '';
  bundleProton = false;

  isLoading = false;
  terminalOutput = '';

  async criarAppImage() {
    this.isLoading = true;
    this.terminalOutput = 'Iniciando empacotamento...\n';

    try {
     
      const resposta = await invoke<string>('executar_proton_pack', {
        appId: this.mode === 'steam' && this.appId ? this.appId : null,
        gameDir: this.mode === 'dir' && this.gameDir ? this.gameDir : null,
        exeRel: this.mode === 'dir' && this.exeRel ? this.exeRel : null,
        displayName: this.mode === 'dir' && this.displayName ? this.displayName : null,
        bundleProton: this.bundleProton,
      });
      
      this.terminalOutput += `\nSUCESSO:\n${resposta}`;
    } catch (erro) {
      this.terminalOutput += `\nERRO:\n${erro}`;
    } finally {
      this.isLoading = false;
    }
  }
}