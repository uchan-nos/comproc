# ComProc project home

![ComProc CPU Board Rev 4 電源入れた状態で斜めから](https://github.com/uchan-nos/comproc/assets/1825663/0ffb9277-a682-495e-86a2-067e0ef378e9)

ComProc プロジェクトの情報まとめページ：https://uchan.net/ublog.cgi/comproc-project

## ディレクトリ構成

    src/                各種ソースコード
      assembler/        アセンブラ
      compiler/         コンパイラ
      cpu/              マイコンのハードウェア記述コード
        board/          各種 CPU ボードのソースコード
        mcu.sv          マイコンのトップモジュール
        cpu.sv          マイコンの CPU
        mem.sv          マイコンの SRAM
        ipl_*.hex       IPL の機械語を格納したファイル（SRAM の初期値）
      e2etest/
        test.sh         コンパイラとマイコンの end-to-end テスト
      examples/         サンプルコード集
        lcd.c           LCD 表示
        sdcard.c        SD カード読み書き
        run-file.sh     プログラムを ComProc ボード上で実行するスクリプト
        build.sh        プログラムをビルドするスクリプト（デバッグに便利）
    tool/               ツール類
      attach_vcom.sh    WSL2 に仮想 COM ポートを接続するスクリプト
      generate-ipl.sh   IPL の機械語ファイルを生成するスクリプト
    workshop/           ワークショップのサンプルコード
