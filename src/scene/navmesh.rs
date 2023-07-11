//! Navigational mesh (navmesh for short) is a surface which can be used for path finding. See [`NavigationalMesh`] docs
//! for more info and usage examples.

use crate::{
    core::{
        math::aabb::AxisAlignedBoundingBox,
        pool::Handle,
        reflect::prelude::*,
        uuid::{uuid, Uuid},
        visitor::prelude::*,
        TypeUuidProvider,
    },
    scene::{base::Base, base::BaseBuilder, graph::Graph, node::Node, node::NodeTrait},
    utils::navmesh::Navmesh,
};
use std::ops::{Deref, DerefMut};

/// Navigational mesh (navmesh for short) is a surface which can be used for path finding. Unlike [A* Pathfinder](crate::utils::astar),
/// it can build arbitrary paths on a surface of large polygons, making a path from point A to point B linear (standard pathfinder builds
/// path only from vertex to vertex). Navmeshes should be used when you have an arbitrary "walkable" surface, for example, a game level
/// with rooms, hallways, multiple floors and so on. A* pathfinder should be used for strategies or any other types of games with uniform
/// pathfinding grid.
///
/// ## How to create
///
/// You should prefer using the navmesh editor to create navigational meshes, however if it is not possible, you can create it manually.
/// Use [`NavigationalMeshBuilder`] to create new instance and add it to your scene graph. Keep in mind, that this node is just a
/// convenient wrapper around [`Navmesh`], so you should also read its docs to get better understanding how it works.
///
/// ```rust
/// # use fyrox::{
/// #     core::{algebra::Vector3, math::TriangleDefinition, pool::Handle},
/// #     scene::{base::BaseBuilder, graph::Graph, navmesh::NavigationalMeshBuilder, node::Node},
/// #     utils::navmesh::Navmesh,
/// # };
/// fn create_navmesh(graph: &mut Graph) -> Handle<Node> {
///     // A simple navmesh with four vertices and two triangles.
///     let navmesh = Navmesh::new(
///         &[TriangleDefinition([0, 1, 2]), TriangleDefinition([0, 2, 3])],
///         &[
///             Vector3::new(-1.0, 0.0, 1.0),
///             Vector3::new(1.0, 0.0, 1.0),
///             Vector3::new(1.0, 0.0, -1.0),
///             Vector3::new(-1.0, 0.0, -1.0),
///         ],
///     );
///     NavigationalMeshBuilder::new(BaseBuilder::new())
///         .with_navmesh(navmesh)
///         .build(graph)
/// }
/// ```
///
/// ## Agents
///
/// Navigational mesh agent helps you to build paths along the surface of a navigational mesh and follow it. Agents can be
/// used to drive the motion of your game characters. Every agent knows about its target and automatically rebuilds the path
/// if the target has moved. Navmesh agents are able to move along the path, providing you with their current position, so you
/// can use it to perform an actual motion of your game characters. Agents work together with navigational meshes, you need
/// to update their state every frame, so they can recalculate path if needed. A simple example could something like this:
///
/// ```rust
/// # use fyrox::utils::navmesh::NavmeshAgent;
/// # struct Foo {
/// // Add this to your script
/// agent: NavmeshAgent
/// # }
/// ```
///
/// After that, you need to update the agent every frame to make sure it will follow the target:
///
/// ```rust
/// # use fyrox::{
/// #    core::algebra::Vector3, scene::navmesh::NavigationalMesh, utils::navmesh::NavmeshAgent,
/// # };
/// fn update_agent(
///     agent: &mut NavmeshAgent,
///     target: Vector3<f32>,
///     dt: f32,
///     navmesh: &mut NavigationalMesh,
/// ) {
///     // Set the target to follow and the speed.
///     agent.set_target(target);
///     agent.set_speed(1.0);
///
///     // Update the agent.
///     agent.update(dt, navmesh.navmesh_mut()).unwrap();
///
///     // Print its position - you can use this position as target point of your game character.
///     println!("{}", agent.position());
/// }
/// ```
///
/// This method should be called in `on_update` of your script. It accepts four parameters: a reference to the agent, a
/// target which it will follow, a time step (`context.dt`), and a reference to navigational mesh node. You can fetch
/// navigational mesh from the scene graph by its name:
///
/// ```rust
/// # use fyrox::scene::{navmesh::NavigationalMesh, Scene};
/// fn find_navmesh<'a>(scene: &'a mut Scene, name: &str) -> &'a mut NavigationalMesh {
///     let handle = scene.graph.find_by_name_from_root(name).unwrap().0;
///     scene.graph[handle].as_navigational_mesh_mut()
/// }
/// ```
#[derive(Debug, Clone, Visit, Reflect, Default)]
pub struct NavigationalMesh {
    base: Base,
    #[reflect(hidden)]
    navmesh: Navmesh,
}

impl TypeUuidProvider for NavigationalMesh {
    fn type_uuid() -> Uuid {
        uuid!("d0ce963c-b50a-4707-bd21-af6dc0d1c668")
    }
}

impl Deref for NavigationalMesh {
    type Target = Base;

    fn deref(&self) -> &Self::Target {
        &self.base
    }
}

impl DerefMut for NavigationalMesh {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.base
    }
}

impl NodeTrait for NavigationalMesh {
    crate::impl_query_component!();

    fn local_bounding_box(&self) -> AxisAlignedBoundingBox {
        self.base.local_bounding_box()
    }

    fn world_bounding_box(&self) -> AxisAlignedBoundingBox {
        self.base.world_bounding_box()
    }

    fn id(&self) -> Uuid {
        Self::type_uuid()
    }
}

impl NavigationalMesh {
    /// Returns a reference to the inner navigational mesh.
    pub fn navmesh_ref(&self) -> &Navmesh {
        &self.navmesh
    }

    /// Returns a reference to the inner navigational mesh.
    pub fn navmesh_mut(&mut self) -> &mut Navmesh {
        &mut self.navmesh
    }
}

/// Creates navigational meshes and adds them to a scene graph.
pub struct NavigationalMeshBuilder {
    base_builder: BaseBuilder,
    navmesh: Navmesh,
}

impl NavigationalMeshBuilder {
    /// Creates new navigational mesh builder.
    pub fn new(base_builder: BaseBuilder) -> Self {
        Self {
            base_builder,
            navmesh: Default::default(),
        }
    }

    /// Sets the actual navigational mesh.
    pub fn with_navmesh(mut self, navmesh: Navmesh) -> Self {
        self.navmesh = navmesh;
        self
    }

    fn build_navigational_mesh(self) -> NavigationalMesh {
        NavigationalMesh {
            base: self.base_builder.build_base(),
            navmesh: self.navmesh,
        }
    }

    /// Creates new navigational mesh instance.
    pub fn build_node(self) -> Node {
        Node::new(self.build_navigational_mesh())
    }

    /// Creates new navigational mesh instance and adds it to the graph.
    pub fn build(self, graph: &mut Graph) -> Handle<Node> {
        graph.add_node(self.build_node())
    }
}
