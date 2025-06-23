# anvil結合テスト実行手順

このディレクトリには、anvil（ローカルEVMノード）上で動作確認を行うための結合テストが含まれています。

## 必要要件
- Foundry（forge）
- anvil（Foundryに同梱）
- .envファイルにPRIVATE_KEYを記載（anvilのアカウント0の秘密鍵）

## テスト実行手順

1. anvilノードを起動（別ターミナルで実行）

```sh
anvil
```

2. .envファイルを作成し、下記を記載

```sh
PRIVATE_KEY=
```

3. このディレクトリのテストを実行

```sh
forge test --fork-url http://127.0.0.1:8545 --match-path 'test/anvil/*'
```

## 備考
- テスト内容は`AnvilIntegration.t.sol`を参照してください。
- 必要に応じてテストケースを追加してください。 