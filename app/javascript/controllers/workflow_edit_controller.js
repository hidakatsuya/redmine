import { Controller } from '@hotwired/stimulus'
import { patch } from '@rails/request.js'

export default class extends Controller {
  static targets = ['form']

  connect() {
    // フォーム送信イベントをStimulusでハンドル
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this.submit.bind(this))
    }
  }

  async submit(event) {
    event.preventDefault()

    const form = this.formTarget
    // 変更項目のみ抽出
    const changed = {}
    const inputs = form.querySelectorAll('input[type="checkbox"], select')
    inputs.forEach(input => {
      if (input.disabled) return
      if (!input.name || !input.name.startsWith('transitions[')) return

      // チェックボックス
      if (input.type === 'checkbox') {
        if (input.defaultChecked !== input.checked) {
          this.setTransitionValue(changed, input.name, input.checked ? "1" : "0")
        }
      }
      // セレクト
      else if (input.tagName === 'SELECT') {
        if (input.defaultValue !== input.value) {
          this.setTransitionValue(changed, input.name, input.value)
        }
      }
    })

    // hidden/その他も必要なら追加
    const extra = {}
    ;['tracker_id[]', 'role_id[]', 'used_statuses_only'].forEach(name => {
      const els = form.querySelectorAll(`input[name="${name}"]`)
      if (els.length) {
        extra[name] = Array.from(els).map(el => el.value)
      }
    })

    const payload = {
      transitions: changed,
      extra: extra
    }

    // PATCHリクエスト送信
    const response = await patch(form.action, {
      body: JSON.stringify(payload),
      contentType: 'application/json',
      responseKind: 'json'
    })

    if (response.ok) {
      const json = await response.json
      if (json.redirect_url) {
        window.location.href = json.redirect_url
      } else {
        alert('保存に失敗しました')
      }
    } else {
      alert('保存に失敗しました')
    }
  }

  setTransitionValue(obj, name, value) {
    // transitions[old][new][rule]形式
    const m = name.match(/^transitions\[(\d+)\]\[(\d+)\]\[(\w+)\]$/)
    if (!m) return
    const [_, old, nw, rule] = m
    if (!obj[old]) obj[old] = {}
    if (!obj[old][nw]) obj[old][nw] = {}
    obj[old][nw][rule] = value
  }
}