import { useUserEditingStore } from '@/stores'
import { useReactFlow } from '@xyflow/react'
import { useEffect } from 'react'
import { useERDContentContext } from './ERDContentContext'

export const useSyncHiddenNodesChange = () => {
  const {
    state: { initializeComplete, onceAutoLayoutComplete },
  } = useERDContentContext()
  const { getNodes, setNodes } = useReactFlow()
  const { hiddenNodeIds } = useUserEditingStore()

  useEffect(() => {
    if (!initializeComplete || !onceAutoLayoutComplete) {
      return
    }
    const nodes = getNodes()
    const updatedNodes = nodes.map((node) => {
      const hidden = hiddenNodeIds.has(node.id)
      return { ...node, hidden }
    })

    console.log('useSyncHiddenNodesChange', 'updatedNodes', updatedNodes)
    //  window.requestAnimationFrame(() => {
     setNodes(updatedNodes)
    //  })
  }, [initializeComplete, getNodes, setNodes, hiddenNodeIds, onceAutoLayoutComplete])
}
