import { useUserEditingActiveStore } from '@/stores'
import { useReactFlow } from '@xyflow/react'
import { useEffect } from 'react'
import { useERDContentContext } from './ERDContentContext'
import { highlightNodesAndEdges } from './highlightNodesAndEdges'

export const useSyncHighlightsActiveTableChange = () => {
  const {
    state: { initializeComplete, onceAutoLayoutComplete },
  } = useERDContentContext()
  const { getNodes, setNodes, getEdges, setEdges } = useReactFlow()
  const { tableName } = useUserEditingActiveStore()

  useEffect(() => {
    if (!initializeComplete || !onceAutoLayoutComplete) {
      return
    }

    const nodes = getNodes()
    const edges = getEdges()
    // この呼び出しいるのか?
    const { nodes: updatedNodes, edges: updatedEdges } = highlightNodesAndEdges(
      nodes,
      edges,
      { activeTableName: tableName },
    )

    //  window.requestAnimationFrame(() => {
    setEdges(updatedEdges)
    console.log('useSyncHighlightsActiveTableChange', 'updatedNodes', updatedNodes)
    setNodes(updatedNodes)
    //  })
  }, [initializeComplete, tableName, getNodes, getEdges, setNodes, setEdges])
}
