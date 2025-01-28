import { Ellipsis } from '@liam-hq/ui'
import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import { useState } from 'react'
import type { FC } from 'react'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'

export const Toolbar: FC = () => {
  const [isOpen, setIsOpen] = useState(false)
  const [hasInteracted, setHasInteracted] = useState(false) // 初回描画判定

  const toggle = () => {
    setIsOpen((prev) => !prev)
    setHasInteracted(true) // 一度でもクリックされたらアニメーション適用
  }

  return (
    <ToolbarPrimitive.Root
      className={`${styles.root} ${
        isOpen
          ? styles.open
          : hasInteracted
          ? styles.closed // 初回以降は閉じるアニメーションを適用
          : styles.initial // 初回描画時のみ適用 (animationなし)
      }`}
    >
      <div className={isOpen ? styles.hidden : styles.buttonContainer}>
        <button onClick={toggle}>
          <Ellipsis color="#FFF" />
        </button>
      </div>
      <div className={!isOpen ? styles.hidden : ''}>
        <ZoomControls setIsOpen={toggle} />
      </div>
    </ToolbarPrimitive.Root>
  )
}
