import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import type { FC } from 'react'
import { FitviewButton } from './FitviewButton'
import { ShowModeMenu } from './ShowModeMenu'
import { TidyUpButton } from './TidyUpButton'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'

export const Toolbar: FC = () => {
  return (
    <ToolbarPrimitive.Root className={styles.root}>
      <ZoomControls />
      <ToolbarPrimitive.ToolbarSeparator className={styles.separator} />
      <div className={styles.buttons}>
        <FitviewButton />
        <TidyUpButton />
        {/* TODO: enable once implemented */}
        {/* <ViewControlButton /> */}
      </div>
      <ShowModeMenu />
    </ToolbarPrimitive.Root>
  )
}
