import { toolbarActionLogEvent } from '@/features/gtm/utils'
import { useVersion } from '@/providers'
import { useUserEditingStore } from '@/stores'
import { IconButton, Scan } from '@liam-hq/ui'
import { ToolbarButton } from '@radix-ui/react-toolbar'
import { useReactFlow } from '@xyflow/react'
import { type FC, useCallback } from 'react'
import styles from './Fitview.module.css'

export const FitviewButton: FC = () => {
  const { fitView } = useReactFlow()
  const { showMode } = useUserEditingStore()
  const { version } = useVersion()

  const handleClick = useCallback(() => {
    toolbarActionLogEvent({
      element: 'fitview',
      showMode,
      platform: version.displayedOn,
      gitHash: version.gitHash,
      ver: version.version,
      appEnv: version.envName,
    })
    fitView()
  }, [fitView, showMode, version])

  return (
    <ToolbarButton asChild onClick={handleClick} className={styles.menuButton}>
      <IconButton icon={<Scan />} tooltipContent="Zoom to Fit">
        Zoom to Fit
      </IconButton>
    </ToolbarButton>
  )
}
